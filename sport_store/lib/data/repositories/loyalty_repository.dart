import '../../models/loyalty.dart';
import '../api/api_client.dart';

/// Контракт Loyalty Service — общего для экосистемы (Runner App + Store + Сайт).
/// Баллы начисляются в любом продукте, баланс единый (Часть 11 RECOMMENDATION).
abstract class LoyaltyRepository {
  Future<LoyaltyAccount> fetchAccount();
  Future<void> postTransaction(LoyaltyTransaction tx);

  /// Серверная трата баллов: бэк проверяет баланс и идемпотентен по orderId.
  /// Возвращает новый баланс. Бросает при недостатке баллов/ошибке.
  Future<int> redeem({
    required int points,
    required String orderId,
    String description,
  });
}

/// Mock: баланс/история живут локально в LoyaltyProvider (prefs).
/// Сетевые методы — заглушки.
class MockLoyaltyRepository implements LoyaltyRepository {
  @override
  Future<LoyaltyAccount> fetchAccount() async =>
      const LoyaltyAccount();

  @override
  Future<void> postTransaction(LoyaltyTransaction tx) async {
    await Future.delayed(const Duration(milliseconds: 150));
  }

  @override
  Future<int> redeem({
    required int points,
    required String orderId,
    String description = '',
  }) async {
    // Офлайн-прототип списывает локально (см. LoyaltyProvider) — сюда не приходит.
    await Future.delayed(const Duration(milliseconds: 120));
    return 0;
  }
}

class ApiLoyaltyRepository implements LoyaltyRepository {
  final ApiClient _client;
  ApiLoyaltyRepository(this._client);

  @override
  Future<LoyaltyAccount> fetchAccount() async {
    final data = await _client.get('/loyalty/account') as Map<String, dynamic>;
    return LoyaltyAccount(
      balance: data['balance'] as int? ?? 0,
      transactions: (data['transactions'] as List? ?? [])
          .map((j) => LoyaltyTransaction.fromJson(j as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<void> postTransaction(LoyaltyTransaction tx) async {
    await _client.post('/loyalty/transactions', body: tx.toJson());
  }

  @override
  Future<int> redeem({
    required int points,
    required String orderId,
    String description = '',
  }) async {
    final data = await _client.post(
      '/loyalty/redeem',
      body: {'amount': points, 'orderId': orderId, 'description': description},
    ) as Map<String, dynamic>;
    return data['balance'] as int? ?? 0;
  }
}
