import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../auth/data/auth_provider.dart';

/// Личная статистика пользователя из общего бэка (GET /v1/me/stats):
/// бег (забеги/км) + баллы (баланс/заработано/потрачено) + заказы (Store).
class MeStats {
  final int runsCount;
  final double totalKm;
  final int balance;
  final int earned;
  final int spent;
  final int ordersCount;
  final int totalSpent;

  const MeStats({
    this.runsCount = 0,
    this.totalKm = 0,
    this.balance = 0,
    this.earned = 0,
    this.spent = 0,
    this.ordersCount = 0,
    this.totalSpent = 0,
  });

  factory MeStats.fromJson(Map<String, dynamic> j) {
    final runs = (j['runs'] as Map?) ?? const {};
    final loyalty = (j['loyalty'] as Map?) ?? const {};
    final orders = (j['orders'] as Map?) ?? const {};
    return MeStats(
      runsCount: (runs['count'] as num?)?.toInt() ?? 0,
      totalKm: (runs['totalKm'] as num?)?.toDouble() ?? 0,
      balance: (loyalty['balance'] as num?)?.toInt() ?? 0,
      earned: (loyalty['earned'] as num?)?.toInt() ?? 0,
      spent: (loyalty['spent'] as num?)?.toInt() ?? 0,
      ordersCount: (orders['count'] as num?)?.toInt() ?? 0,
      totalSpent: (orders['totalSpent'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Тянет статистику при открытии экрана; autoDispose — перезапрашивается заново.
final meStatsProvider = FutureProvider.autoDispose<MeStats>((ref) async {
  final token = ref.read(authProvider).token;
  if (token == null || token.isEmpty) {
    throw Exception('Не авторизован');
  }
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json', 'Connection': 'close'},
    ),
  );
  final r = await dio.get<Map<String, dynamic>>(
    '/me/stats',
    options: Options(headers: {'Authorization': 'Bearer $token'}),
  );
  return MeStats.fromJson(r.data ?? const {});
});
