import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _Header(tab: _tab, onTabChanged: (t) => setState(() => _tab = t)),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  _PersonalLeaderboard(),
                  _ClubsLeaderboard(),
                  _DistrictsLeaderboard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTabChanged;
  const _Header({required this.tab, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
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
                      'Неделя 22 · Якутск',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.separator),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.calendar,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Эта неделя',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
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

// ── Data ───────────────────────────────────────────────────────────────────

class _Player {
  final int rank;
  final String name, club, km;
  final bool isMe;
  const _Player({
    required this.rank,
    required this.name,
    required this.club,
    required this.km,
    required this.isMe,
  });
}

const _players = [
  _Player(
    rank: 1,
    name: 'Айаал Петров',
    club: 'Yakutia Runners',
    km: '142.3',
    isMe: false,
  ),
  _Player(
    rank: 2,
    name: 'Михаил Сидоров',
    club: 'Arctic Running',
    km: '138.7',
    isMe: false,
  ),
  _Player(
    rank: 3,
    name: 'Сардаана К.',
    club: 'Yakutia Runners',
    km: '131.2',
    isMe: false,
  ),
  _Player(rank: 4, name: 'Ты', club: 'Arctic Running', km: '124.5', isMe: true),
  _Player(
    rank: 5,
    name: 'Нюргун А.',
    club: 'Бегуны Якутска',
    km: '119.8',
    isMe: false,
  ),
  _Player(
    rank: 6,
    name: 'Ольга В.',
    club: 'Yakutia Runners',
    km: '108.4',
    isMe: false,
  ),
  _Player(
    rank: 7,
    name: 'Степан М.',
    club: 'Arctic Running',
    km: '97.1',
    isMe: false,
  ),
];

// ── Personal leaderboard ───────────────────────────────────────────────────

class _PersonalLeaderboard extends StatelessWidget {
  const _PersonalLeaderboard();

  @override
  Widget build(BuildContext context) {
    final me = _players.firstWhere((p) => p.isMe);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _PodiumCard(players: _players.take(3).toList()),
        const SizedBox(height: 10),
        _MyPositionBanner(player: me),
        const SizedBox(height: 12),
        ..._players.skip(3).map((p) => _PlayerTile(player: p)),
      ],
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final List<_Player> players;
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
            children: [
              const Icon(
                CupertinoIcons.rosette,
                color: AppColors.warning,
                size: 15,
              ),
              const SizedBox(width: 5),
              const Text(
                'Топ недели',
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
  final _Player player;
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
    final color = _medalColors[player.rank - 1];
    final avatarR = isFirst ? 27.0 : 21.0;

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
                player.name[0],
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
            player.name.split(' ')[0],
            style: TextStyle(
              fontSize: 12,
              fontWeight: isFirst ? FontWeight.w700 : FontWeight.w500,
              color: isFirst ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 1),
          Text(
            '${player.km} км',
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
  final _Player player;
  const _MyPositionBanner({required this.player});

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
              '#${player.rank}',
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
                  '${player.km} км · ${player.club}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            CupertinoIcons.arrow_up,
            color: AppColors.success,
            size: 14,
          ),
          const SizedBox(width: 2),
          const Text(
            '+2',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final _Player player;
  const _PlayerTile({required this.player});

  @override
  Widget build(BuildContext context) {
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
              player.name[0],
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.isMe ? '${player.name} (вы)' : player.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: player.isMe
                        ? AppColors.electricBlue
                        : AppColors.textPrimary,
                  ),
                ),
                Text(player.club, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            '${player.km} км',
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

// ── Clubs leaderboard ──────────────────────────────────────────────────────

class _ClubData {
  final String name;
  final int km, members;
  final Color color;
  const _ClubData({
    required this.name,
    required this.km,
    required this.members,
    required this.color,
  });
}

const _clubs = [
  _ClubData(
    name: 'Yakutia Runners',
    km: 1247,
    members: 34,
    color: AppColors.warning,
  ),
  _ClubData(
    name: 'Arctic Running',
    km: 1089,
    members: 28,
    color: Color(0xFFB0BEC5),
  ),
  _ClubData(
    name: 'Бегуны Якутска',
    km: 876,
    members: 21,
    color: Color(0xFFCD7F32),
  ),
  _ClubData(
    name: 'Северный темп',
    km: 654,
    members: 15,
    color: AppColors.textSecondary,
  ),
];

class _ClubsLeaderboard extends StatelessWidget {
  const _ClubsLeaderboard();

  @override
  Widget build(BuildContext context) {
    final maxKm = _clubs.first.km.toDouble();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _clubs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = _clubs[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.separator),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: c.color,
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
                          c.name,
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
                    '${c.km} км',
                    style: TextStyle(
                      color: c.color,
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
                  value: c.km / maxKm,
                  minHeight: 4,
                  backgroundColor: AppColors.bgElevated,
                  valueColor: AlwaysStoppedAnimation(c.color),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Districts leaderboard ──────────────────────────────────────────────────

class _DistrictData {
  final String name, owner;
  final int zones;
  final double fill;
  const _DistrictData({
    required this.name,
    required this.owner,
    required this.zones,
    required this.fill,
  });
}

const _districts = [
  _DistrictData(
    name: 'Октябрьский',
    owner: 'Yakutia Runners',
    zones: 89,
    fill: 0.72,
  ),
  _DistrictData(
    name: 'Строительный',
    owner: 'Arctic Running',
    zones: 72,
    fill: 0.58,
  ),
  _DistrictData(
    name: 'Сергелях',
    owner: 'Бегуны Якутска',
    zones: 64,
    fill: 0.52,
  ),
  _DistrictData(name: 'Центр', owner: 'Yakutia Runners', zones: 55, fill: 0.44),
  _DistrictData(name: 'Табага', owner: 'Северный темп', zones: 41, fill: 0.33),
];

class _DistrictsLeaderboard extends StatelessWidget {
  const _DistrictsLeaderboard();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _districts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final d = _districts[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.separator),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.electricBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  CupertinoIcons.building_2_fill,
                  color: AppColors.electricBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      d.owner,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.electricBlue,
                      ),
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: d.fill,
                        minHeight: 4,
                        backgroundColor: AppColors.bgElevated,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.electricBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${d.zones}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text('зон', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
