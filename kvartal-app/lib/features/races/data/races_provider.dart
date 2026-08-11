import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../auth/data/auth_provider.dart';

/// Беговое соревнование (старт) для вкладки «Старты».
/// Данные с общего backend (`GET /v1/races`). JSON — camelCase, парсим защитно.
class RaceEvent {
  final int id;
  final String title;
  final String city;
  final String region;
  final String place;
  final String type;
  final String typeLabel;
  final String regStatus; // open | soon | closed | done
  final String regUrl;
  final String description;
  final String coverUrl;
  final DateTime? date;
  final List<String> distances;
  final int points;

  const RaceEvent({
    required this.id,
    required this.title,
    required this.city,
    required this.region,
    required this.place,
    required this.type,
    required this.typeLabel,
    required this.regStatus,
    required this.regUrl,
    required this.description,
    required this.coverUrl,
    required this.date,
    required this.distances,
    required this.points,
  });

  factory RaceEvent.fromJson(Map<String, dynamic> j) => RaceEvent(
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: j['title']?.toString() ?? '',
        city: j['city']?.toString() ?? '',
        region: j['region']?.toString() ?? '',
        place: j['place']?.toString() ?? '',
        type: j['type']?.toString() ?? 'other',
        typeLabel: j['typeLabel']?.toString() ?? '',
        regStatus: j['regStatus']?.toString() ?? 'soon',
        regUrl: j['regUrl']?.toString() ?? '',
        description: j['description']?.toString() ?? '',
        coverUrl: ApiConfig.resolveMedia(j['coverUrl']?.toString() ?? ''),
        date: DateTime.tryParse(j['date']?.toString() ?? ''),
        distances: ((j['distances'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        points: (j['points'] as num?)?.toInt() ?? 0,
      );

  bool get isPast {
    final d = date;
    if (d == null) return false;
    final now = DateTime.now();
    return d.isBefore(DateTime(now.year, now.month, now.day));
  }
}

/// Лента «Стартов»: забеги + разрешённый регион клиента (для подписи в шапке).
class RacesFeed {
  final List<RaceEvent> items;
  final String region; // человекочитаемое имя региона, напр. «Республика Саха (Якутия)»
  const RacesFeed({required this.items, required this.region});
}

final _racesDio = Dio(BaseOptions(
  baseUrl: ApiConfig.baseUrl,
  connectTimeout: ApiConfig.connectTimeout,
  receiveTimeout: ApiConfig.receiveTimeout,
  headers: {'Content-Type': 'application/json', 'Connection': 'close'},
));

/// Афиша забегов (публичный эндпоинт — токен не нужен). СТРОГО по региону клиента:
/// шлём город из профиля Квартала (`city`), бэкенд отдаёт только забеги этого региона
/// (Якутск → Республика Саха; Москва → Москва и область). Регион меняется — лента
/// перезапрашивается. TODO: добавить GPS lat/lng; авто-парсер источников (Celery).
final racesProvider = FutureProvider.autoDispose<RacesFeed>((ref) async {
  final city = ref.watch(authProvider.select((s) => s.user?.city))?.trim() ?? '';
  final res = await _racesDio.get<Map<String, dynamic>>(
    '/races',
    queryParameters: {if (city.isNotEmpty) 'city': city},
  );
  final items = (res.data?['races'] as List? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(RaceEvent.fromJson)
      .toList();
  return RacesFeed(
    items: items,
    region: res.data?['region']?.toString() ?? '',
  );
});
