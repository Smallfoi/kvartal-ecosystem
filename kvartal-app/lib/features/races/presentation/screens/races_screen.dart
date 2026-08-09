import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/races_provider.dart';

const _months = [
  '', 'янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
];

class _TypeStyle {
  final List<Color> grad;
  final String emoji;
  const _TypeStyle(this.grad, this.emoji);
}

_TypeStyle _typeStyle(String type) {
  switch (type) {
    case 'trail':
      return const _TypeStyle([Color(0xFF12543A), Color(0xFF0A2418)], '🌲');
    case 'night':
      return const _TypeStyle([Color(0xFF3A2170), Color(0xFF140B2C)], '🌙');
    case 'fest':
      return const _TypeStyle([Color(0xFF8A3B12), Color(0xFF331405)], '🎉');
    case 'relay':
      return const _TypeStyle([Color(0xFF0D5C63), Color(0xFF082224)], '🤝');
    case 'kids':
      return const _TypeStyle([Color(0xFF8A5A12), Color(0xFF2A1A05)], '🧒');
    default:
      return const _TypeStyle([Color(0xFF123A7A), Color(0xFF0B1B39)], '🏃');
  }
}

class _StatusStyle {
  final Color color;
  final String label;
  const _StatusStyle(this.color, this.label);
}

_StatusStyle _statusStyle(String s) {
  switch (s) {
    case 'open':
      return const _StatusStyle(AppColors.success, 'Регистрация');
    case 'closed':
      return const _StatusStyle(AppColors.textTertiary, 'Регистрация закрыта');
    case 'done':
      return const _StatusStyle(AppColors.textTertiary, 'Завершён');
    default:
      return const _StatusStyle(AppColors.warning, 'Скоро');
  }
}

class RacesScreen extends ConsumerStatefulWidget {
  const RacesScreen({super.key});

  @override
  ConsumerState<RacesScreen> createState() => _RacesScreenState();
}

class _RacesScreenState extends ConsumerState<RacesScreen> {
  int _segment = 0; // 0 = ближайшие, 1 = прошедшие

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(racesProvider);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1628), AppColors.bgDark],
          stops: [0.0, 0.32],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 2),
              child: Text(
                'Старты',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Календарь беговых событий',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: _Segmented(
                index: _segment,
                labels: const ['Ближайшие', 'Прошедшие'],
                onChanged: (i) => setState(() => _segment = i),
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.electricBlue),
                ),
                error: (_, __) =>
                    const _Empty('Не удалось загрузить старты. Проверьте связь.'),
                data: (all) {
                  final list = all.where((r) => _segment == 0 ? !r.isPast : r.isPast).toList();
                  list.sort((a, b) {
                    final da = a.date, db = b.date;
                    if (da == null || db == null) return 0;
                    return _segment == 0 ? da.compareTo(db) : db.compareTo(da);
                  });
                  if (list.isEmpty) {
                    return _Empty(_segment == 0 ? 'Пока нет ближайших стартов' : 'Архив пуст');
                  }
                  return RefreshIndicator(
                    color: AppColors.electricBlue,
                    onRefresh: () => ref.refresh(racesProvider.future),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (_, i) => _RaceCard(race: list[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  const _Segmented({required this.index, required this.labels, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1526),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.separator),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.bgCard : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: i == index ? Colors.white : AppColors.textTertiary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
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

class _RaceCard extends StatelessWidget {
  final RaceEvent race;
  const _RaceCard({required this.race});

  @override
  Widget build(BuildContext context) {
    final ts = _typeStyle(race.type);
    final ss = _statusStyle(race.regStatus);
    final d = race.date;
    return GestureDetector(
      onTap: () => context.push('/races/detail', extra: race),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.separator),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // cover
            SizedBox(
              height: race.isPast ? 96 : 124,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: ts.grad,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -6,
                    top: 8,
                    child: Opacity(
                      opacity: 0.16,
                      child: Text(ts.emoji, style: const TextStyle(fontSize: 92)),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC060A14)],
                        stops: [0.35, 1.0],
                      ),
                    ),
                  ),
                  if (race.typeLabel.isNotEmpty)
                    Positioned(
                      left: 12,
                      top: 12,
                      child: _pill(race.typeLabel, const Color(0xCFCFE0FF), const Color(0xFF06101F)),
                    ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _statusPill(ss),
                  ),
                  if (d != null)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: _dateChip(d),
                    ),
                ],
              ),
            ),
            // body
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    race.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.location_solid,
                          size: 13, color: AppColors.electricBlue),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          [race.city, race.place].where((s) => s.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                  if (!race.isPast && race.distances.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final dist in race.distances)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E1A2E),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.separator),
                            ),
                            child: Text(
                              dist,
                              style: const TextStyle(
                                color: Color(0xFFC7D4EA),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (!race.isPast && race.points > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(CupertinoIcons.circle_grid_hex_fill,
                            size: 14, color: AppColors.success),
                        const SizedBox(width: 6),
                        Text(
                          '+${race.points} баллов за финиш',
                          style: const TextStyle(
                              color: AppColors.success, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _pill(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  static Widget _statusPill(_StatusStyle ss) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0x99080E1A),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: ss.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(ss.label,
                style: TextStyle(color: ss.color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  static Widget _dateChip(DateTime d) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0x80060A14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              d.day.toString().padLeft(2, '0'),
              style: const TextStyle(
                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 0.95),
            ),
            Text(
              _months[d.month].toUpperCase(),
              style: const TextStyle(
                  color: Color(0xFFCDD9EE), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
          ],
        ),
      );
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.calendar, size: 44, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
