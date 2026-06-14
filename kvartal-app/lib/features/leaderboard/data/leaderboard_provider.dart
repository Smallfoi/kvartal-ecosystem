import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../auth/data/auth_provider.dart';

/// Рейтинг — по пробежанным КМ (источник правды — backend, D-11).
/// км = заработанное за бег за период (не баланс кошелька), периоды week/month/all.

class LeaderUser {
  final String userId;
  final String name;
  final double km;
  final String? club;
  final int rank;
  final bool isMe;

  const LeaderUser({
    required this.userId,
    required this.name,
    required this.km,
    required this.rank,
    required this.isMe,
    this.club,
  });

  factory LeaderUser.fromJson(Map<String, dynamic> j) => LeaderUser(
    userId: j['userId']?.toString() ?? '',
    name: j['name']?.toString() ?? '—',
    km: (j['km'] as num?)?.toDouble() ?? 0,
    club: j['club']?.toString(),
    rank: (j['rank'] as num?)?.toInt() ?? 0,
    isMe: j['isMe'] == true,
  );
}

class UsersBoard {
  final List<LeaderUser> top;
  final int? myRank;
  final double myKm;
  const UsersBoard({required this.top, required this.myKm, this.myRank});
}

class LeaderClub {
  final String id;
  final String name;
  final String? logo;
  final int members;
  final double km;
  final int rank;
  final bool isMine;

  const LeaderClub({
    required this.id,
    required this.name,
    required this.members,
    required this.km,
    required this.rank,
    required this.isMine,
    this.logo,
  });

  factory LeaderClub.fromJson(Map<String, dynamic> j) => LeaderClub(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? '—',
    logo: j['logo']?.toString(),
    members: (j['members'] as num?)?.toInt() ?? 0,
    km: (j['km'] as num?)?.toDouble() ?? 0,
    rank: (j['rank'] as num?)?.toInt() ?? 0,
    isMine: j['isMine'] == true,
  );
}

class ClubsBoard {
  final List<LeaderClub> top;
  final int? myRank;
  const ClubsBoard({required this.top, this.myRank});
}

final _leaderboardDio = Dio(
  BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: ApiConfig.connectTimeout,
    receiveTimeout: ApiConfig.receiveTimeout,
    // 'Connection: close' — свежее соединение на запрос (см. PITFALLS: Dio keep-alive
    // поверх adb reverse даёт "Connection closed before full header").
    headers: {'Content-Type': 'application/json', 'Connection': 'close'},
  ),
);

/// Выбранный период рейтинга: 'week' | 'month'.
final leaderboardPeriodProvider = StateProvider<String>((_) => 'week');

final leaderboardUsersProvider = FutureProvider.autoDispose<UsersBoard>((ref) async {
  final period = ref.watch(leaderboardPeriodProvider);
  final token = ref.watch(authProvider).token;
  if (token == null || token.isEmpty) {
    return const UsersBoard(top: [], myKm: 0);
  }
  final res = await _leaderboardDio.get<Map<String, dynamic>>(
    '/leaderboard/users',
    queryParameters: {'period': period},
    options: Options(headers: {'Authorization': 'Bearer $token'}),
  );
  final data = res.data ?? {};
  final top = (data['top'] as List? ?? [])
      .whereType<Map<String, dynamic>>()
      .map(LeaderUser.fromJson)
      .toList();
  final me = (data['me'] as Map<String, dynamic>?) ?? const {};
  return UsersBoard(
    top: top,
    myRank: (me['rank'] as num?)?.toInt(),
    myKm: (me['km'] as num?)?.toDouble() ?? 0,
  );
});

final leaderboardClubsProvider = FutureProvider.autoDispose<ClubsBoard>((ref) async {
  final period = ref.watch(leaderboardPeriodProvider);
  final token = ref.watch(authProvider).token;
  if (token == null || token.isEmpty) {
    return const ClubsBoard(top: []);
  }
  final res = await _leaderboardDio.get<Map<String, dynamic>>(
    '/leaderboard/clubs',
    queryParameters: {'period': period},
    options: Options(headers: {'Authorization': 'Bearer $token'}),
  );
  final data = res.data ?? {};
  final top = (data['top'] as List? ?? [])
      .whereType<Map<String, dynamic>>()
      .map(LeaderClub.fromJson)
      .toList();
  return ClubsBoard(top: top, myRank: (data['myRank'] as num?)?.toInt());
});
