import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../loyalty/data/loyalty_provider.dart';
import 'completed_runs_provider.dart';

enum RunStatus { idle, active, paused }

const activeRunStorageKey = 'kvartal.active_run.v1';
const activeRunSchemaVersion = 2;
const _maxRunSpeedMs = 11.1;
const _minRoutePointDistanceMeters = 2.0;
const _maxRoutePointGapMeters = 40.0;
const _maxAcceptedAccuracyMeters = 35.0;
// EMA-сглаживание трека: тянет каждую новую точку к предыдущей и убирает
// дрожь GPS («звёзды» на границе территории). 0 = не двигаемся, 1 = без сглаживания.
const _smoothingAlpha = 0.35;
const _locationServiceChannel = MethodChannel('kvartal/location_service');

class RunState {
  final RunStatus status;
  final List<LatLng> route;
  final Duration elapsed;
  final double distanceMeters;

  const RunState({
    this.status = RunStatus.idle,
    this.route = const [],
    this.elapsed = Duration.zero,
    this.distanceMeters = 0,
  });

  double get distanceKm => distanceMeters / 1000;

  int get paceSeconds {
    if (distanceKm < 0.01 || elapsed.inSeconds == 0) return 0;
    return (elapsed.inSeconds / distanceKm).round();
  }

  String get paceFormatted {
    if (paceSeconds == 0) return '--:--';
    final m = paceSeconds ~/ 60;
    final s = paceSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get elapsedFormatted {
    final h = elapsed.inHours;
    final m = elapsed.inMinutes % 60;
    final s = elapsed.inSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  RunState copyWith({
    RunStatus? status,
    List<LatLng>? route,
    Duration? elapsed,
    double? distanceMeters,
  }) {
    return RunState(
      status: status ?? this.status,
      route: route ?? this.route,
      elapsed: elapsed ?? this.elapsed,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }
}

class RunNotifier extends StateNotifier<RunState> {
  final Ref _ref;
  RunNotifier(this._ref) : super(const RunState()) {
    unawaited(_restoreSavedRun());
  }

  Timer? _timer;
  StreamSubscription<Position>? _foregroundPositionSub;

  Future<void> start() async {
    debugPrint('KVARTAL_RUN_START_TAP');
    if (state.status == RunStatus.active) return;

    final canTrack = await _ensureLocationReady();
    if (!canTrack) {
      debugPrint('KVARTAL_RUN_START_LOCATION_NOT_READY');
      return;
    }

    debugPrint('KVARTAL_RUN_START_LOCATION_READY');
    state = state.copyWith(
      status: RunStatus.active,
      route: state.status == RunStatus.idle ? [] : state.route,
      distanceMeters: state.status == RunStatus.idle ? 0 : state.distanceMeters,
      elapsed: state.status == RunStatus.idle ? Duration.zero : state.elapsed,
    );

    debugPrint('KVARTAL_RUN_START_STATE_ACTIVE');
    unawaited(_seedCurrentPosition());
    unawaited(_persistRun());
    unawaited(_startNativeLocationService());
    _startTimer();
    _startForegroundTracking();
  }

  Future<void> _startNativeLocationService() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _locationServiceChannel.invokeMethod('startLocationService');
      debugPrint('KVARTAL_RUN_NATIVE_LOCATION_SERVICE_STARTED');
    } catch (error) {
      debugPrint('KVARTAL_RUN_NATIVE_LOCATION_SERVICE_START_ERROR: $error');
    }
  }

  Future<void> _stopNativeLocationService() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _locationServiceChannel.invokeMethod('stopLocationService');
      debugPrint('KVARTAL_RUN_NATIVE_LOCATION_SERVICE_STOPPED');
    } catch (error) {
      debugPrint('KVARTAL_RUN_NATIVE_LOCATION_SERVICE_STOP_ERROR: $error');
    }
  }

  Future<void> _ensureNotificationPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final status = await permissions.Permission.notification.status;
      if (status.isDenied) {
        await permissions.Permission.notification.request();
      }
    } catch (error) {
      debugPrint('KVARTAL_RUN_NOTIFICATION_PERMISSION_ERROR: $error');
    }
  }

  Future<bool> _ensureLocationReady() async {
    try {
      await _ensureNotificationPermission();

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (error, stackTrace) {
      debugPrint('KVARTAL_RUN_LOCATION_PERMISSION_ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> _seedCurrentPosition() async {
    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: _foregroundLocationSettings(),
      );
      await _applyPosition(current, force: true);
    } catch (error) {
      debugPrint('KVARTAL_RUN_GPS_SEED_ERROR: $error');
    }
  }

  void _startForegroundTracking() {
    debugPrint('KVARTAL_RUN_FOREGROUND_STREAM_START');
    unawaited(_foregroundPositionSub?.cancel());
    _foregroundPositionSub =
        Geolocator.getPositionStream(
          locationSettings: _foregroundLocationSettings(),
        ).listen(
          (position) => unawaited(_applyPosition(position)),
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('KVARTAL_RUN_FOREGROUND_STREAM_ERROR: $error');
            debugPrintStack(stackTrace: stackTrace);
          },
        );
  }

  Future<void> _applyPosition(Position position, {bool force = false}) async {
    if (state.status != RunStatus.active) return;
    if (!force && position.accuracy > _maxAcceptedAccuracyMeters) return;
    if (!force && position.speed > _maxRunSpeedMs) return;

    final raw = LatLng(position.latitude, position.longitude);
    final route = [...state.route];
    var distanceMeters = state.distanceMeters;

    var next = raw;
    if (route.isNotEmpty) {
      final last = route.last;
      final rawGap = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        raw.latitude,
        raw.longitude,
      );
      // микродрожание на месте — игнорируем
      if (!force && rawGap < _minRoutePointDistanceMeters) return;
      // явный телепорт (спайк GPS) — отбрасываем ДО сглаживания
      if (!force && rawGap > _maxRoutePointGapMeters) {
        debugPrint('KVARTAL_RUN_GPS_JUMP_REJECTED: ${rawGap.toStringAsFixed(1)}m');
        return;
      }
      // EMA-сглаживание: тянем точку к предыдущей, убираем дрожь («звёзды»).
      if (!force) {
        next = LatLng(
          last.latitude + _smoothingAlpha * (raw.latitude - last.latitude),
          last.longitude + _smoothingAlpha * (raw.longitude - last.longitude),
        );
      }
      distanceMeters += Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        next.latitude,
        next.longitude,
      );
    }

    route.add(next);
    state = state.copyWith(route: route, distanceMeters: distanceMeters);
    await _persistRun();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(
        elapsed: state.elapsed + const Duration(seconds: 1),
      );
      if (state.elapsed.inSeconds % 5 == 0) {
        unawaited(_persistRun());
      }
    });
  }

  void pause() {
    if (state.status != RunStatus.active) return;
    _timer?.cancel();
    unawaited(_foregroundPositionSub?.cancel());
    unawaited(_stopNativeLocationService());
    _foregroundPositionSub = null;
    state = state.copyWith(status: RunStatus.paused);
    unawaited(_persistRun());
  }

  void resume() {
    if (state.status != RunStatus.paused) return;
    unawaited(start());
  }

  void stop({int capturedZones = 0, bool capturedTerritory = false}) {
    final completed = state;
    _timer?.cancel();
    unawaited(_foregroundPositionSub?.cancel());
    unawaited(_stopNativeLocationService());
    _foregroundPositionSub = null;
    if (completed.route.length > 1 || completed.distanceMeters > 0) {
      unawaited(_saveCompletedRun(completed, capturedZones, capturedTerritory));
    }
    state = const RunState();
    unawaited(_clearSavedRun());
  }

  void reset() {
    _timer?.cancel();
    unawaited(_foregroundPositionSub?.cancel());
    unawaited(_stopNativeLocationService());
    _foregroundPositionSub = null;
    state = const RunState();
    unawaited(_clearSavedRun());
  }

  Future<void> _saveCompletedRun(
    RunState completed,
    int capturedZones,
    bool capturedTerritory,
  ) async {
    final run = CompletedRun(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      finishedAt: DateTime.now(),
      route: completed.route,
      elapsed: completed.elapsed,
      distanceMeters: completed.distanceMeters,
      capturedZones: capturedZones,
      capturedTerritory: capturedTerritory,
    );
    await _ref.read(completedRunsProvider.notifier).add(run);
    await _awardLoyaltyPoints(run);
  }

  /// Начисление баллов в общий счёт экосистемы за пробежку и захват территории.
  /// 10 баллов/км + 50 за захват территории (как в демо-экономике бэка).
  /// Баллы становятся видны и в Store (общий аккаунт).
  Future<void> _awardLoyaltyPoints(CompletedRun run) async {
    final loyalty = _ref.read(loyaltyProvider.notifier);
    final runPoints = (run.distanceKm * 10).round();
    if (runPoints > 0) {
      await loyalty.award(
        amount: runPoints,
        source: 'runnerRun',
        description: 'Пробежка ${run.distanceKm.toStringAsFixed(1)} км',
        runId: run.id,
      );
    }
    if (run.capturedTerritory) {
      final zonesNote = run.capturedZones > 0 ? ' (${run.capturedZones} зон)' : '';
      await loyalty.award(
        amount: 50,
        source: 'runnerTerritory',
        description: 'Захват территории$zonesNote',
        runId: run.id,
      );
    }
  }

  Future<void> _restoreSavedRun() async {
    try {
      final restored = await _readSavedRun(applyElapsedDelta: true);
      if (restored == null || restored.status == RunStatus.idle) {
        await _clearSavedRun();
        return;
      }

      state = restored;
      if (restored.status == RunStatus.active) {
        unawaited(_startNativeLocationService());
        _startTimer();
        _startForegroundTracking();
      }
    } catch (error) {
      debugPrint('KVARTAL_RUN_RESTORE_ERROR: $error');
      await _clearSavedRun();
    }
  }

  Future<RunState?> _readSavedRun({required bool applyElapsedDelta}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(activeRunStorageKey);
    if (raw == null) return null;

    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['schemaVersion'] != activeRunSchemaVersion) return null;

    final statusName = data['status'] as String? ?? RunStatus.idle.name;
    final restoredStatus = RunStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => RunStatus.idle,
    );
    if (restoredStatus == RunStatus.idle) return null;

    final route = ((data['route'] as List?) ?? const [])
        .whereType<List>()
        .where((p) => p.length >= 2)
        .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList();

    if (route.isEmpty) return null;

    var elapsed = Duration(
      seconds: (data['elapsedSeconds'] as num? ?? 0).toInt(),
    );
    final savedAtMs = (data['savedAtMs'] as num?)?.toInt();
    if (applyElapsedDelta &&
        restoredStatus == RunStatus.active &&
        savedAtMs != null) {
      elapsed += DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(savedAtMs),
      );
    }

    return RunState(
      status: restoredStatus,
      route: route,
      elapsed: elapsed,
      distanceMeters: (data['distanceMeters'] as num? ?? 0).toDouble(),
    );
  }

  Future<void> _persistRun() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    var route = state.route;
    var distanceMeters = state.distanceMeters;
    final raw = prefs.getString(activeRunStorageKey);
    if (raw != null && state.status == RunStatus.active) {
      try {
        final saved = jsonDecode(raw) as Map<String, dynamic>;
        final savedRoute = ((saved['route'] as List?) ?? const [])
            .whereType<List>()
            .where((p) => p.length >= 2)
            .map(
              (p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
            )
            .toList();
        if (savedRoute.length > route.length) {
          route = savedRoute;
          distanceMeters = (saved['distanceMeters'] as num? ?? distanceMeters)
              .toDouble();
          state = state.copyWith(route: route, distanceMeters: distanceMeters);
        }
      } catch (_) {
        // Ignore malformed saved state; the new state below will replace it.
      }
    }

    final data = {
      'schemaVersion': activeRunSchemaVersion,
      'status': state.status.name,
      'elapsedSeconds': state.elapsed.inSeconds,
      'distanceMeters': distanceMeters,
      'savedAtMs': DateTime.now().millisecondsSinceEpoch,
      'route': [
        for (final p in route) [p.latitude, p.longitude],
      ],
    };
    await prefs.setString(activeRunStorageKey, jsonEncode(data));
  }

  Future<void> _clearSavedRun() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(activeRunStorageKey);
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_foregroundPositionSub?.cancel());
    super.dispose();
  }
}

LocationSettings _foregroundLocationSettings() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 1),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'КВАРТАЛ записывает пробежку',
        notificationText: 'GPS активен. Маршрут сохраняется в фоне.',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  }

  return const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 0,
  );
}

final runProvider = StateNotifierProvider<RunNotifier, RunState>(
  (ref) => RunNotifier(ref),
);
