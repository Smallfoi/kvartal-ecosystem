import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../auth/data/auth_provider.dart';

/// Баллы лояльности — общий счёт экосистемы (тот же backend, что и аккаунт).
/// Квартал начисляет баллы за бег/территории, Store их тратит. Здесь — чтение
/// общего баланса через GET /loyalty/account (источник правды — backend).
class LoyaltyTxn {
  final int amount;
  final String source;
  final String description;
  final String? createdAt;

  const LoyaltyTxn({
    required this.amount,
    required this.source,
    required this.description,
    this.createdAt,
  });

  factory LoyaltyTxn.fromJson(Map<String, dynamic> json) => LoyaltyTxn(
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    source: json['source']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    createdAt: json['createdAt']?.toString(),
  );
}

class LoyaltyState {
  final int balance;
  final String level;
  final List<LoyaltyTxn> transactions;
  final bool isLoading;
  final bool loaded;
  final String? error;

  const LoyaltyState({
    this.balance = 0,
    this.level = 'basic',
    this.transactions = const [],
    this.isLoading = false,
    this.loaded = false,
    this.error,
  });

  LoyaltyState copyWith({
    int? balance,
    String? level,
    List<LoyaltyTxn>? transactions,
    bool? isLoading,
    bool? loaded,
    String? error,
    bool clearError = false,
  }) => LoyaltyState(
    balance: balance ?? this.balance,
    level: level ?? this.level,
    transactions: transactions ?? this.transactions,
    isLoading: isLoading ?? this.isLoading,
    loaded: loaded ?? this.loaded,
    error: clearError ? null : error ?? this.error,
  );

  /// Русское название уровня по порогам экосистемы (0/200/500/1000).
  String get levelTitle => switch (level) {
    'platinum' => 'Платина',
    'gold' => 'Золото',
    'silver' => 'Серебро',
    _ => 'Базовый',
  };
}

class LoyaltyNotifier extends StateNotifier<LoyaltyState> {
  final Ref ref;

  LoyaltyNotifier(this.ref) : super(const LoyaltyState());

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      // 'Connection: close' — каждый запрос на свежем соединении. Иначе Dio
      // переиспользует keep-alive, который uvicorn закрывает по таймауту, и
      // поверх adb reverse это даёт "Connection closed before full header".
      headers: {'Content-Type': 'application/json', 'Connection': 'close'},
    ),
  );

  Future<void> refresh() async {
    if (state.isLoading) return; // дедуп: не пускаем два запроса разом
    final token = ref.read(authProvider).token;
    if (token == null || token.isEmpty) {
      state = const LoyaltyState();
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/loyalty/account',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data ?? {};
      final txns = (data['transactions'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(LoyaltyTxn.fromJson)
          .toList();
      state = state.copyWith(
        balance: (data['balance'] as num?)?.toInt() ?? 0,
        level: data['level']?.toString() ?? 'basic',
        transactions: txns,
        isLoading: false,
        loaded: true,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Не удалось загрузить баллы');
    }
  }
}

final loyaltyProvider =
    StateNotifierProvider<LoyaltyNotifier, LoyaltyState>((ref) {
  final notifier = LoyaltyNotifier(ref);
  // Подтягиваем баланс, когда пользователь авторизовался (или уже авторизован).
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
