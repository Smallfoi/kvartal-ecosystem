import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../run/data/completed_runs_provider.dart';

class ClubScreen extends StatelessWidget {
  const ClubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: CustomScrollView(
        slivers: [
          const _ClubSliverHeader(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionHeader(title: 'Участники', trailing: '2 онлайн'),
                const SizedBox(height: 10),
                const _MembersList(),
                const SizedBox(height: 24),
                _SectionHeader(title: 'Клубные вызовы', trailing: '2 активных'),
                const SizedBox(height: 10),
                const _ClubChallenges(),
                const SizedBox(height: 24),
                _SectionHeader(title: 'Захваченные районы'),
                const SizedBox(height: 10),
                const _TerritoryCard(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sliver header ──────────────────────────────────────────────────────────

class _ClubSliverHeader extends StatelessWidget {
  const _ClubSliverHeader();

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 210,
      pinned: true,
      backgroundColor: AppColors.bgDark,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          child: IconButton(
            icon: const Icon(
              CupertinoIcons.person_add,
              color: AppColors.electricBlue,
              size: 20,
            ),
            onPressed: () {},
          ),
        ),
      ],
      title: Text('Клуб', style: Theme.of(context).textTheme.titleLarge),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D1F3C), Color(0xFF0A1628), AppColors.bgDark],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.electricBlue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.electricBlue.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.bolt_fill,
                          color: AppColors.electricBlue,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Arctic Running',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '28 участников',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          '#2 клуб',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.separator),
                    ),
                    child: const Row(
                      children: [
                        _ClubStat(label: 'км за неделю', value: '1 089'),
                        _StatDivider(),
                        _ClubStat(label: 'зон на карте', value: '312'),
                        _StatDivider(),
                        _ClubStat(label: 'побед', value: '47'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClubStat extends StatelessWidget {
  final String label, value;
  const _ClubStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.electricBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: AppColors.separator);
}

// ── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
      ],
    );
  }
}

// ── Members ────────────────────────────────────────────────────────────────

class _MembersList extends ConsumerWidget {
  const _MembersList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(completedRunsProvider);
    final myKm = runs.fold<double>(0, (s, r) => s + r.distanceKm);
    // «Ты» — реальный километраж из своих пробежек. Остальные участники пока
    // демо: настоящие данные клуба требуют бэкенда клубов (его ещё нет).
    final members = <(String, String, bool)>[
      ('Айаал П.', '138.7 км', true),
      ('Ты', '${myKm.toStringAsFixed(1)} км', true),
      ('Степан М.', '97.1 км', false),
      ('Нюргун С.', '88.4 км', false),
    ]..sort((a, b) => _parseKm(b.$2).compareTo(_parseKm(a.$2)));

    return Column(
      children: members
          .map((m) => _MemberTile(name: m.$1, km: m.$2, isOnline: m.$3))
          .toList(),
    );
  }
}

double _parseKm(String s) =>
    double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

class _MemberTile extends StatelessWidget {
  final String name, km;
  final bool isOnline;
  const _MemberTile({
    required this.name,
    required this.km,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.bgElevated,
                child: Text(
                  name[0],
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bgCard, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: AppColors.textPrimary),
            ),
          ),
          Text(
            km,
            style: const TextStyle(
              color: AppColors.electricBlue,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Challenges ─────────────────────────────────────────────────────────────

class _ClubChallenges extends StatelessWidget {
  const _ClubChallenges();

  @override
  Widget build(BuildContext context) {
    const challenges = [
      ('Битва районов', 'Суммарно 500 км за 48ч', 0.68, '14ч'),
      ('Марафон недели', 'Каждый по 20 км', 0.45, '3 дня'),
    ];

    return Column(
      children: challenges.map((c) {
        final (title, desc, progress, timeLeft) = c;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.separator),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.clock,
                          size: 10,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          timeLeft,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(desc, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppColors.bgElevated,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.electricBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.electricBlue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Territory card ─────────────────────────────────────────────────────────

class _TerritoryCard extends StatelessWidget {
  const _TerritoryCard();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Строительный', 72, AppColors.electricBlue),
      ('Центр', 55, AppColors.accentBlue),
      ('Сергелях', 41, AppColors.info),
      ('Другие', 28, AppColors.textSecondary),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _TerritoryItem(
                label: items[0].$1,
                zones: items[0].$2,
                color: items[0].$3,
              ),
              const SizedBox(width: 8),
              _TerritoryItem(
                label: items[1].$1,
                zones: items[1].$2,
                color: items[1].$3,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _TerritoryItem(
                label: items[2].$1,
                zones: items[2].$2,
                color: items[2].$3,
              ),
              const SizedBox(width: 8),
              _TerritoryItem(
                label: items[3].$1,
                zones: items[3].$2,
                color: items[3].$3,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TerritoryItem extends StatelessWidget {
  final String label;
  final int zones;
  final Color color;
  const _TerritoryItem({
    required this.label,
    required this.zones,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$zones зон',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
