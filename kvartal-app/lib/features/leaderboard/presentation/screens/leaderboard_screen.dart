import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/leaderboard_provider.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      // Фоновый градиент (синий сверху → чёрный) — как на профиле и в клубе.
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1628), AppColors.bgDark],
            stops: [0.0, 0.32],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(tab: _tab, onTabChanged: (t) => setState(() => _tab = t)),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: const [
                    _PersonalTab(),
                    _ClubsTab(),
                    _DistrictsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final int tab;
  final ValueChanged<int> onTabChanged;
  const _Header({required this.tab, required this.onTabChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(leaderboardPeriodProvider);
    final periodLabel = period == 'month' ? 'Этот месяц' : 'Эта неделя';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Рейтинг',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800, height: 1.1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$periodLabel · Якутск',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              _PeriodToggle(period: period),
            ],
          ),
          const SizedBox(height: 16),
          _SegmentedControl(
            selected: tab,
            onChanged: onTabChanged,
            labels: const ['Личный', 'Клубы', 'Районы'],
          ),
        ],
      ),
    );
  }
}

class _PeriodToggle extends ConsumerWidget {
  final String period;
  const _PeriodToggle({required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget seg(String value, String label) {
      final active = period == value;
      return GestureDetector(
        onTap: () => ref.read(leaderboardPeriodProvider.notifier).state = value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.electricBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.separator),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg('week', 'Неделя'), seg('month', 'Месяц')],
      ),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  final List<String> labels;
  const _SegmentedControl({
    required this.selected,
    required this.onChanged,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: labels.asMap().entries.map((entry) {
          final isSelected = entry.key == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.electricBlue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  entry.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Общие состояния ──────────────────────────────────────────────────────────

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.only(top: 60),
      child: CircularProgressIndicator(),
    ),
  );
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary),
      ),
    ),
  );
}

// ── Личный ───────────────────────────────────────────────────────────────────

class _PersonalTab extends ConsumerWidget {
  const _PersonalTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaderboardUsersProvider);
    return async.when(
      loading: () => const _Loading(),
      error: (_, __) => const _Empty('Не удалось загрузить рейтинг'),
      data: (board) {
        if (board.top.isEmpty) {
          return const _Empty(
            'Пока нет пробежек за период.\nПробегись — и попадёшь в рейтинг!',
          );
        }
        final hasPodium = board.top.length >= 3;
        final podium = board.top.take(3).toList();
        final rest = board.top.skip(hasPodium ? 3 : 0).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (hasPodium) ...[
              _PodiumCard(players: podium),
              const SizedBox(height: 10),
            ],
            if (board.myRank != null) ...[
              _MyPositionBanner(rank: board.myRank!, km: board.myKm),
              const SizedBox(height: 12),
            ],
            ...rest.map((p) => _PlayerTile(player: p)),
          ],
        );
      },
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final List<LeaderUser> players;
  const _PodiumCard({required this.players});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(CupertinoIcons.rosette, color: AppColors.warning, size: 15),
              SizedBox(width: 5),
              Text(
                'Топ периода',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _PodiumItem(player: players[1], height: 72),
              _PodiumItem(player: players[0], height: 96, isFirst: true),
              _PodiumItem(player: players[2], height: 56),
            ],
          ),
        ],
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  final LeaderUser player;
  final double height;
  final bool isFirst;
  const _PodiumItem({
    required this.player,
    required this.height,
    this.isFirst = false,
  });

  static const _medalColors = [
    AppColors.warning,
    Color(0xFFB0BEC5),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context) {
    final idx = (player.rank - 1).clamp(0, 2);
    final color = _medalColors[idx];
    final avatarR = isFirst ? 27.0 : 21.0;
    final initial = player.name.isNotEmpty ? player.name[0].toUpperCase() : '?';

    return Expanded(
      child: Column(
        children: [
          if (isFirst) ...[
            const Icon(
              CupertinoIcons.rosette,
              color: AppColors.warning,
              size: 20,
            ),
            const SizedBox(height: 4),
          ] else
            const SizedBox(height: 24),
          Container(
            width: avatarR * 2,
            height: avatarR * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
              border: Border.all(color: color, width: isFirst ? 2.5 : 1.5),
              boxShadow: isFirst
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: isFirst ? 20 : 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            player.isMe ? 'Вы' : player.name.split(' ').first,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isFirst ? FontWeight.w700 : FontWeight.w500,
              color: player.isMe
                  ? AppColors.electricBlue
                  : (isFirst ? AppColors.textPrimary : AppColors.textSecondary),
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 1),
          Text(
            '${player.km.toStringAsFixed(1)} км',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            child: Container(
              height: height,
              width: double.infinity,
              color: color.withValues(alpha: 0.13),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '#${player.rank}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyPositionBanner extends StatelessWidget {
  final int rank;
  final double km;
  const _MyPositionBanner({required this.rank, required this.km});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.electricBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.electricBlue.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.electricBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ваше место',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                Text(
                  '${km.toStringAsFixed(1)} км',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final LeaderUser player;
  const _PlayerTile({required this.player});

  @override
  Widget build(BuildContext context) {
    final initial = player.name.isNotEmpty ? player.name[0].toUpperCase() : '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: player.isMe
            ? AppColors.electricBlue.withValues(alpha: 0.10)
            : AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: player.isMe
              ? AppColors.electricBlue.withValues(alpha: 0.35)
              : AppColors.separator,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '#${player.rank}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: player.isMe
                    ? AppColors.electricBlue
                    : AppColors.textSecondary,
              ),
            ),
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.bgElevated,
            child: Text(
              initial,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.isMe ? '${player.name} · Вы' : player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: player.isMe
                        ? AppColors.electricBlue
                        : AppColors.textPrimary,
                  ),
                ),
                if (player.club != null && player.club!.isNotEmpty)
                  Text(
                    player.club!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          Text(
            '${player.km.toStringAsFixed(1)} км',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: player.isMe
                  ? AppColors.electricBlue
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Клубы ────────────────────────────────────────────────────────────────────

class _ClubsTab extends ConsumerWidget {
  const _ClubsTab();

  static const _rankColors = [
    AppColors.warning,
    Color(0xFFB0BEC5),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaderboardClubsProvider);
    return async.when(
      loading: () => const _Loading(),
      error: (_, __) => const _Empty('Не удалось загрузить рейтинг клубов'),
      data: (board) {
        if (board.top.isEmpty) {
          return const _Empty(
            'Пока нет клубов с активностью.\nСоздай клуб и беги за команду!',
          );
        }
        final maxKm = board.top
            .map((c) => c.km)
            .fold<double>(0, (m, v) => v > m ? v : m);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: board.top.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final c = board.top[i];
            final color = i < 3 ? _rankColors[i] : AppColors.textSecondary;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.isMine
                    ? AppColors.electricBlue.withValues(alpha: 0.10)
                    : AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: c.isMine
                      ? AppColors.electricBlue.withValues(alpha: 0.35)
                      : AppColors.separator,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${c.rank}',
                          style: TextStyle(
                            color: color,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.isMine ? '${c.name} · ваш клуб' : c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${c.members} участников',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${c.km.toStringAsFixed(1)} км',
                        style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxKm > 0 ? c.km / maxKm : 0,
                      minHeight: 4,
                      backgroundColor: AppColors.bgElevated,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Районы: контроль территорий клубами (D-09, реальные данные с PostGIS) ─────

class _DistrictsTab extends ConsumerWidget {
  const _DistrictsTab();

  static const _rankColors = [
    AppColors.warning,
    Color(0xFFB0BEC5),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaderboardDistrictsProvider);
    return async.when(
      loading: () => const _Loading(),
      error: (_, __) =>
          const _Empty('Не удалось загрузить контроль территорий'),
      data: (board) {
        if (board.top.isEmpty) {
          return const _Empty(
            'Пока никто не удерживает территории.\n'
            'Замкни маршрут на карте и захвати квартал за свой клуб!',
          );
        }
        final maxArea = board.top
            .map((c) => c.areaM2)
            .fold<double>(0, (m, v) => v > m ? v : m);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: board.top.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            if (idx == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6, top: 2, left: 2),
                child: Text(
                  'Контроль территорий · удержание 7 дней',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              );
            }
            final c = board.top[idx - 1];
            final color = (idx - 1) < 3
                ? _rankColors[idx - 1]
                : AppColors.textSecondary;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.isMine
                    ? AppColors.electricBlue.withValues(alpha: 0.10)
                    : AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: c.isMine
                      ? AppColors.electricBlue.withValues(alpha: 0.35)
                      : AppColors.separator,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${c.rank}',
                          style: TextStyle(
                            color: color,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.isMine ? '${c.name} · ваш клуб' : c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              c.pieces == 1
                                  ? '1 территория'
                                  : '${c.pieces} территорий',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        c.areaLabel,
                        style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxArea > 0 ? c.areaM2 / maxArea : 0,
                      minHeight: 4,
                      backgroundColor: AppColors.bgElevated,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
