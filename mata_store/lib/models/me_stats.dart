/// Личная статистика пользователя (общий бэкенд: GET /v1/me/stats).
/// Агрегаты одинаковы во всех приложениях экосистемы.
class MeStats {
  final int runsCount; // забегов (Квартал)
  final double totalKm; // суммарные км (без флаг-забегов)
  final int balance; // текущий баланс баллов
  final int earned; // баллов заработано всего
  final int spent; // баллов потрачено всего
  final int ordersCount; // заказов (Store)
  final int totalSpent; // сумма заказов, ₽

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
