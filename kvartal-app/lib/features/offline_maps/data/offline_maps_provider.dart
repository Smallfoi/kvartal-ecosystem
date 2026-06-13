import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OfflineMapStatus { notDownloaded, downloading, downloaded, failed }

const offlineCityMapPrefsKey = 'kvartal.offline_maps.yakutsk.v1';

class OfflineCityMapState {
  final String id;
  final String name;
  final String region;
  final String version;
  final int minZoom;
  final int maxZoom;
  final int totalTiles;
  final int downloadedTiles;
  final int estimatedSizeMb;
  final OfflineMapStatus status;
  final DateTime? downloadedAt;
  final DateTime? updatedAt;
  final String? errorMessage;
  final bool allowCellularUpdates;
  final String? tileUrlTemplate;

  const OfflineCityMapState({
    required this.id,
    required this.name,
    required this.region,
    required this.version,
    required this.minZoom,
    required this.maxZoom,
    required this.totalTiles,
    required this.downloadedTiles,
    required this.estimatedSizeMb,
    required this.status,
    required this.allowCellularUpdates,
    this.downloadedAt,
    this.updatedAt,
    this.errorMessage,
    this.tileUrlTemplate,
  });

  double get progress => totalTiles == 0 ? 0 : downloadedTiles / totalTiles;
  bool get isDownloaded => status == OfflineMapStatus.downloaded;
  bool get isDownloading => status == OfflineMapStatus.downloading;

  OfflineCityMapState copyWith({
    int? totalTiles,
    int? downloadedTiles,
    int? estimatedSizeMb,
    OfflineMapStatus? status,
    DateTime? downloadedAt,
    DateTime? updatedAt,
    String? errorMessage,
    bool? allowCellularUpdates,
    String? tileUrlTemplate,
    bool clearError = false,
    bool clearTileUrlTemplate = false,
    bool clearDownloadedAt = false,
    bool clearUpdatedAt = false,
  }) {
    return OfflineCityMapState(
      id: id,
      name: name,
      region: region,
      version: version,
      minZoom: minZoom,
      maxZoom: maxZoom,
      totalTiles: totalTiles ?? this.totalTiles,
      downloadedTiles: downloadedTiles ?? this.downloadedTiles,
      estimatedSizeMb: estimatedSizeMb ?? this.estimatedSizeMb,
      status: status ?? this.status,
      downloadedAt: clearDownloadedAt
          ? null
          : downloadedAt ?? this.downloadedAt,
      updatedAt: clearUpdatedAt ? null : updatedAt ?? this.updatedAt,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      allowCellularUpdates: allowCellularUpdates ?? this.allowCellularUpdates,
      tileUrlTemplate: clearTileUrlTemplate
          ? null
          : tileUrlTemplate ?? this.tileUrlTemplate,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'downloadedTiles': downloadedTiles,
    'totalTiles': totalTiles,
    'estimatedSizeMb': estimatedSizeMb,
    'downloadedAtMs': downloadedAt?.millisecondsSinceEpoch,
    'updatedAtMs': updatedAt?.millisecondsSinceEpoch,
    'allowCellularUpdates': allowCellularUpdates,
    'tileUrlTemplate': tileUrlTemplate,
  };
}

class OfflineMapsNotifier extends StateNotifier<OfflineCityMapState> {
  OfflineMapsNotifier() : super(_initialState()) {
    unawaited(_restore());
  }

  static const _prefsKey = offlineCityMapPrefsKey;
  static const _tileUrl =
      'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';

  static const _minLat = 61.94;
  static const _maxLat = 62.12;
  static const _minLng = 129.58;
  static const _maxLng = 129.88;

  static OfflineCityMapState _initialState() {
    final total = _countTiles(12, 15);
    return OfflineCityMapState(
      id: 'yakutsk',
      name: '\u042f\u043a\u0443\u0442\u0441\u043a',
      region:
          '\u0420\u0435\u0441\u043f\u0443\u0431\u043b\u0438\u043a\u0430 \u0421\u0430\u0445\u0430',
      version: '2026.06',
      minZoom: 12,
      maxZoom: 15,
      totalTiles: total,
      downloadedTiles: 0,
      estimatedSizeMb: 65,
      status: OfflineMapStatus.notDownloaded,
      allowCellularUpdates: false,
    );
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final statusName = data['status'] as String?;
      final status = OfflineMapStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => OfflineMapStatus.notDownloaded,
      );
      state = state.copyWith(
        status: status == OfflineMapStatus.downloading
            ? OfflineMapStatus.notDownloaded
            : status,
        downloadedTiles: data['downloadedTiles'] as int? ?? 0,
        totalTiles: data['totalTiles'] as int? ?? state.totalTiles,
        estimatedSizeMb:
            data['estimatedSizeMb'] as int? ?? state.estimatedSizeMb,
        downloadedAt: _dateFromMs(data['downloadedAtMs']),
        updatedAt: _dateFromMs(data['updatedAtMs']),
        allowCellularUpdates: data['allowCellularUpdates'] as bool? ?? false,
        tileUrlTemplate: data['tileUrlTemplate'] as String?,
      );
    } catch (_) {
      state = state.copyWith(status: OfflineMapStatus.notDownloaded);
    }
  }

  Future<void> downloadYakutsk() async {
    if (state.isDownloading) return;

    final root = await _cityDirectory();
    await root.create(recursive: true);

    state = state.copyWith(
      status: OfflineMapStatus.downloading,
      downloadedTiles: 0,
      totalTiles: _countTiles(state.minZoom, state.maxZoom),
      clearError: true,
    );

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {'User-Agent': 'com.kvartal.kvartal_app'},
      ),
    );

    var done = 0;
    try {
      for (final tile in _tiles(state.minZoom, state.maxZoom)) {
        final file = File('${root.path}/${tile.z}/${tile.x}/${tile.y}.png');
        if (await file.exists()) {
          done++;
          _publishProgress(done);
          continue;
        }

        await file.parent.create(recursive: true);
        await dio.download(_tileUrlFor(tile), file.path);
        done++;
        _publishProgress(done);
      }

      final now = DateTime.now();
      state = state.copyWith(
        status: OfflineMapStatus.downloaded,
        downloadedTiles: done,
        downloadedAt: now,
        updatedAt: now,
        tileUrlTemplate: _localTemplate(root),
        clearError: true,
      );
      await _save();
    } catch (e) {
      state = state.copyWith(
        status: OfflineMapStatus.failed,
        downloadedTiles: done,
        errorMessage: e.toString(),
      );
      await _save();
    }
  }

  Future<void> updateYakutsk() => downloadYakutsk();

  Future<void> deleteYakutsk() async {
    final root = await _cityDirectory();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    state = state.copyWith(
      status: OfflineMapStatus.notDownloaded,
      downloadedTiles: 0,
      clearDownloadedAt: true,
      clearUpdatedAt: true,
      clearTileUrlTemplate: true,
      clearError: true,
    );
    await _save();
  }

  Future<void> setAllowCellularUpdates(bool value) async {
    state = state.copyWith(allowCellularUpdates: value);
    await _save();
  }

  void _publishProgress(int done) {
    if (done == state.downloadedTiles) return;
    state = state.copyWith(downloadedTiles: done);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
  }

  static DateTime? _dateFromMs(Object? value) {
    if (value is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  static String _tileUrlFor(_TileId tile) => _tileUrl
      .replaceAll('{z}', '${tile.z}')
      .replaceAll('{x}', '${tile.x}')
      .replaceAll('{y}', '${tile.y}');

  static String _localTemplate(Directory root) {
    final path = root.path.replaceAll('\\', '/');
    return '$path/{z}/{x}/{y}.png';
  }

  Future<Directory> _cityDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/offline_maps/yakutsk/cartodb_voyager');
  }

  static int _countTiles(int minZoom, int maxZoom) =>
      _tiles(minZoom, maxZoom).length;

  static List<_TileId> _tiles(int minZoom, int maxZoom) {
    final result = <_TileId>[];
    for (var z = minZoom; z <= maxZoom; z++) {
      final a = _tileFor(_minLat, _minLng, z);
      final b = _tileFor(_maxLat, _maxLng, z);
      final minX = min(a.x, b.x);
      final maxX = max(a.x, b.x);
      final minY = min(a.y, b.y);
      final maxY = max(a.y, b.y);

      for (var x = minX; x <= maxX; x++) {
        for (var y = minY; y <= maxY; y++) {
          result.add(_TileId(z, x, y));
        }
      }
    }
    return result;
  }

  static _TileId _tileFor(double lat, double lng, int z) {
    final n = pow(2.0, z).toDouble();
    final x = ((lng + 180.0) / 360.0 * n).floor();
    final latRad = lat * pi / 180.0;
    final y = ((1.0 - log(tan(latRad) + 1 / cos(latRad)) / pi) / 2.0 * n)
        .floor();
    return _TileId(z, x, y);
  }
}

class _TileId {
  final int z;
  final int x;
  final int y;

  const _TileId(this.z, this.x, this.y);
}

final offlineMapsProvider =
    StateNotifierProvider<OfflineMapsNotifier, OfflineCityMapState>(
      (_) => OfflineMapsNotifier(),
    );

Future<bool> isYakutskOfflineMapDownloaded() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(offlineCityMapPrefsKey);
  if (raw == null) return false;

  try {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return data['status'] == OfflineMapStatus.downloaded.name &&
        (data['tileUrlTemplate'] as String?) != null;
  } catch (_) {
    return false;
  }
}
