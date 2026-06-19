import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_config.dart';
import '../../auth/data/auth_provider.dart';

/// Кроссовки пользователя — связка экосистемы Store ↔ Квартал (ECOSYSTEM_API §2.5).
/// Куплены в Store (сервер создаёт ресурс при заказе), Квартал убавляет
/// километраж после пробежек: `GET /shoes`, `POST /shoes/{id}/distance`.
class ShoeAsset {
  final String id;
  final String productId;
  final String orderId;
  final String model;
  final String imageUrl;
  final double totalKm;
  final double maxKm;
  final double remainingKm;
  final int wearPercent;
  final bool retired;

  const ShoeAsset({
    required this.id,
    required this.productId,
    required this.orderId,
    required this.model,
    required this.imageUrl,
    required this.totalKm,
    required this.maxKm,
    required this.remainingKm,
    required this.wearPercent,
    required this.retired,
  });

  factory ShoeAsset.fromJson(Map<String, dynamic> j) {
    final total = (j['totalKm'] as num?)?.toDouble() ?? 0;
    final max = (j['maxKm'] as num?)?.toDouble() ?? 600;
    return ShoeAsset(
      id: j['id']?.toString() ?? '',
      productId: j['productId']?.toString() ?? '',
      orderId: j['orderId']?.toString() ?? '',
      model: j['model']?.toString() ?? 'Кроссовки',
      imageUrl: j['imageUrl']?.toString() ?? '',
      totalKm: total,
      maxKm: max,
      remainingKm:
          (j['remainingKm'] as num?)?.toDouble() ?? (max - total).clamp(0, max),
      wearPercent: (j['wearPercent'] as num?)?.toInt() ??
          (max > 0 ? (total / max * 100).clamp(0, 100).round() : 0),
      retired: j['retired'] == true,
    );
  }
}

class ShoesState {
  final List<ShoeAsset> shoes;
  final bool isLoading;
  final bool loaded;
  final String? error;

  const ShoesState({
    this.shoes = const [],
    this.isLoading = false,
    this.loaded = false,
    this.error,
  });

  ShoesState copyWith({
    List<ShoeAsset>? shoes,
    bool? isLoading,
    bool? loaded,
    String? error,
    bool clearError = false,
  }) =>
      ShoesState(
        shoes: shoes ?? this.shoes,
        isLoading: isLoading ?? this.isLoading,
        loaded: loaded ?? this.loaded,
        error: clearError ? null : error ?? this.error,
      );

  /// Активная пара = самая свежая не списанная (на неё идёт пробег).
  ShoeAsset? get active {
    for (final s in shoes) {
      if (!s.retired) return s;
    }
    return null;
  }

  bool get hasShoes => shoes.isNotEmpty;
}

class ShoesNotifier extends StateNotifier<ShoesState> {
  final Ref ref;

  ShoesNotifier(this.ref) : super(const ShoesState());

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json', 'Connection': 'close'},
    ),
  );

  static const _pendingKey = 'kvartal.shoes.pending.v1';

  Future<void> refresh() async {
    if (state.isLoading) return;
    final token = ref.read(authProvider).token;
    if (token == null || token.isEmpty) {
      state = const ShoesState();
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    // Сначала досылаем накопленные «пробежки», затем читаем актуальный список.
    await _flushPending(token);
    try {
      final response = await _dio.get<List<dynamic>>(
        '/shoes',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final shoes = (response.data ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ShoeAsset.fromJson)
          .toList();
      state = state.copyWith(
        shoes: shoes,
        isLoading: false,
        loaded: true,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Не удалось загрузить кроссовки',
      );
    }
  }

  /// После пробежки списать [km] с активной пары. Идемпотентно по [runId]
  /// (офлайн-очередь может переслать одну пробежку повторно — сервер не задвоит).
  /// На улице связи с dev-беком нет → начисление кладётся в очередь и долетит
  /// при следующем refresh (открытие профиля / экрана кроссовок).
  Future<void> applyRunDistance({
    required double km,
    required String runId,
  }) async {
    if (km <= 0) return;
    // Нужны данные о кроссовках, чтобы знать активную пару.
    if (!state.loaded) await refresh();
    final active = state.active;
    if (active == null) return; // нет активных кроссовок — изнашивать нечего
    await _enqueue({'shoeId': active.id, 'km': km, 'runId': runId});
    await refresh();
  }

  Future<void> _enqueue(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _readPending(prefs)..add(item);
    await prefs.setString(_pendingKey, jsonEncode(list));
  }

  List<Map<String, dynamic>> _readPending(SharedPreferences prefs) {
    final raw = prefs.getString(_pendingKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Досылает очередь по порядку; на первой сетевой ошибке стоп и сохраняем остаток.
  Future<void> _flushPending(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = _readPending(prefs);
    if (pending.isEmpty) return;
    final remaining = <Map<String, dynamic>>[];
    for (var i = 0; i < pending.length; i++) {
      final item = pending[i];
      final shoeId = item['shoeId']?.toString() ?? '';
      if (shoeId.isEmpty) continue; // битый элемент — пропускаем
      try {
        await _dio.post<Map<String, dynamic>>(
          '/shoes/$shoeId/distance',
          data: {'km': item['km'], 'runId': item['runId']},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      } catch (_) {
        remaining.addAll(pending.sublist(i)); // офлайн — остаток оставляем
        break;
      }
    }
    await prefs.setString(_pendingKey, jsonEncode(remaining));
  }
}

final shoesProvider = StateNotifierProvider<ShoesNotifier, ShoesState>((ref) {
  final notifier = ShoesNotifier(ref);
  ref.listen<AuthState>(authProvider, (prev, next) {
    if (next.status == AuthStatus.authenticated && next.token != prev?.token) {
      notifier.refresh();
    }
  });
  if (ref.read(authProvider).status == AuthStatus.authenticated) {
    notifier.refresh();
  }
  return notifier;
});
