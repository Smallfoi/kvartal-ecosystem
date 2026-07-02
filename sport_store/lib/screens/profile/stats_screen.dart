import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

/// Личная статистика пользователя из общего бэка (/v1/me/stats):
/// бег (Квартал) + баллы + заказы (Store) — единая витрина экосистемы.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final Future<MeStats> _future =
      context.read<AuthProvider>().fetchStats();

  static String _km(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(title: const Text('Моя статистика')),
      body: FutureBuilder<MeStats>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Не удалось загрузить статистику.\nПроверьте подключение и попробуйте позже.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.grey600),
                ),
              ),
            );
          }
          final s = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _SectionTitle('Бег'),
              _StatRow([
                _Stat('Забегов', '${s.runsCount}', Icons.directions_run),
                _Stat('Дистанция', '${_km(s.totalKm)} км', Icons.route_outlined),
              ]),
              const SizedBox(height: 22),
              const _SectionTitle('Баллы'),
              _StatRow([
                _Stat('Баланс', '${s.balance}', Icons.star_border),
                _Stat('Заработано', '${s.earned}', Icons.trending_up),
                _Stat('Потрачено', '${s.spent}', Icons.trending_down),
              ]),
              const SizedBox(height: 22),
              const _SectionTitle('Заказы'),
              _StatRow([
                _Stat('Заказов', '${s.ordersCount}', Icons.shopping_bag_outlined),
                _Stat('На сумму', '${s.totalSpent} ₽', Icons.payments_outlined),
              ]),
              const SizedBox(height: 24),
              const Text(
                'Статистика едина во всех приложениях экосистемы: бег и баллы '
                'зарабатываются в «Квартале», покупки — здесь.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.grey600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      );
}

class _Stat {
  final String label;
  final String value;
  final IconData icon;
  const _Stat(this.label, this.value, this.icon);
}

class _StatRow extends StatelessWidget {
  final List<_Stat> stats;
  const _StatRow(this.stats);

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight даёт Row ограниченную высоту (= самая высокая карточка),
    // тогда stretch выравнивает карточки по высоте без «неограниченной высоты»
    // в ListView (иначе секции ниже первой рендерились пустыми).
    final children = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 10));
      children.add(Expanded(child: _StatCard(stats[i])));
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final _Stat stat;
  const _StatCard(this.stat);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(stat.icon, size: 22, color: AppColors.black),
            const SizedBox(height: 10),
            Text(
              stat.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              stat.label,
              style: const TextStyle(fontSize: 12, color: AppColors.grey600),
            ),
          ],
        ),
      );
}
