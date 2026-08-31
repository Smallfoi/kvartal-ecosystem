import 'package:flutter/cupertino.dart';

import '../../run/data/completed_runs_provider.dart';

/// Факты, по которым считаются медали (клиентская логика, как в профиле).
class BadgeFacts {
  final int runs;
  final double totalKm;
  final int captures;
  final int balance;

  const BadgeFacts({
    this.runs = 0,
    this.totalKm = 0,
    this.captures = 0,
    this.balance = 0,
  });

  factory BadgeFacts.fromRuns(
    List<CompletedRun> list, {
    required int balance,
  }) => BadgeFacts(
    runs: list.length,
    totalKm: list.fold<double>(0, (s, r) => s + r.distanceKm),
    captures: list.where((r) => r.capturedTerritory).length,
    balance: balance,
  );
}

/// Медаль: плита формы знака (Ф1/Ф4, утверждено 31.08.2026).
class BadgeDef {
  final String id;
  final String title;

  /// За что выдана — строка на церемонии и в трофейном зале.
  final String reason;
  final IconData icon;
  final bool Function(BadgeFacts f) unlocked;

  const BadgeDef({
    required this.id,
    required this.title,
    required this.reason,
    required this.icon,
    required this.unlocked,
  });
}

/// Реестр медалей. Порядок = порядок в трофейном зале.
const kBadgeDefs = <BadgeDef>[
  BadgeDef(
    id: 'first-run',
    title: 'Арктический',
    reason: 'Первая пробежка — самая трудная. Она сделана.',
    icon: CupertinoIcons.snow,
    unlocked: _firstRun,
  ),
  BadgeDef(
    id: 'sprint-5',
    title: 'Спринтер',
    reason: '5 километров суммарно.',
    icon: CupertinoIcons.bolt_fill,
    unlocked: _km5,
  ),
  BadgeDef(
    id: 'series-7',
    title: 'Серия 7',
    reason: '7 пробежек. Постоянство сильнее скорости.',
    icon: CupertinoIcons.flame_fill,
    unlocked: _runs7,
  ),
  BadgeDef(
    id: 'city-10',
    title: 'Якутск',
    reason: '10 километров по родному городу.',
    icon: CupertinoIcons.moon_stars_fill,
    unlocked: _km10,
  ),
  BadgeDef(
    id: 'legend-500',
    title: 'Легенда',
    reason: '500 баллов МАТА на счету.',
    icon: CupertinoIcons.star_fill,
    unlocked: _balance500,
  ),
  BadgeDef(
    id: 'captures-3',
    title: 'Высотник',
    reason: '3 захваченных квартала.',
    icon: CupertinoIcons.location_north_fill,
    unlocked: _captures3,
  ),
];

bool _firstRun(BadgeFacts f) => f.runs >= 1;
bool _km5(BadgeFacts f) => f.totalKm >= 5;
bool _runs7(BadgeFacts f) => f.runs >= 7;
bool _km10(BadgeFacts f) => f.totalKm >= 10;
bool _balance500(BadgeFacts f) => f.balance >= 500;
bool _captures3(BadgeFacts f) => f.captures >= 3;
