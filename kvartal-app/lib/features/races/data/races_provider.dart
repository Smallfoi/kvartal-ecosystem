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

/// Лента «Стартов»: забеги + подпись выбранного режима/региона (для шапки).
class RacesFeed {
  final List<RaceEvent> items;
  final String region; // подпись: «Республика Саха (Якутия)» / «Вся Россия» / «Крупные марафоны»
  const RacesFeed({required this.items, required this.region});
}

/// Режим показа афиши (переключатель региона в шапке «Стартов»).
enum RegionMode { myRegion, all, majors, region }

/// Текущий выбор региона. По умолчанию — «мой регион» (из профиля/GPS).
class RegionSelection {
  final RegionMode mode;
  final String slug; // для mode == region
  final String label; // запасная подпись до загрузки ленты
  const RegionSelection({this.mode = RegionMode.myRegion, this.slug = '', this.label = ''});

  static const my = RegionSelection();
  static const russia = RegionSelection(mode: RegionMode.all, label: 'Вся Россия');
  static const majors = RegionSelection(mode: RegionMode.majors, label: 'Крупные марафоны');
  factory RegionSelection.region(String slug, String name) =>
      RegionSelection(mode: RegionMode.region, slug: slug, label: name);
}

/// Выбранный режим/регион. Меняется из пикера — лента перезапрашивается.
final raceSelectionProvider = StateProvider<RegionSelection>((ref) => RegionSelection.my);

/// Регион с забегами (для пикера «показать другой регион»).
class RaceRegion {
  final String slug;
  final String name;
  final int count;
  const RaceRegion({required this.slug, required this.name, required this.count});
  factory RaceRegion.fromJson(Map<String, dynamic> j) => RaceRegion(
        slug: j['slug']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

final _racesDio = Dio(BaseOptions(
  baseUrl: ApiConfig.baseUrl,
  connectTimeout: ApiConfig.connectTimeout,
  receiveTimeout: ApiConfig.receiveTimeout,
  headers: {'Content-Type': 'application/json', 'Connection': 'close'},
));

/// Афиша забегов (публичный эндпоинт — токен не нужен). Режим выбирается пикером:
/// «мой регион» (город из профиля), «вся Россия», «крупные марафоны» или конкретный
/// регион (слаг). Меняется выбор — лента перезапрашивается.
/// TODO: GPS lat/lng для «мой регион»; авто-парсер источников (Celery).
final racesProvider = FutureProvider.autoDispose<RacesFeed>((ref) async {
  final sel = ref.watch(raceSelectionProvider);
  final city = ref.watch(authProvider.select((s) => s.user?.city))?.trim() ?? '';

  final qp = <String, dynamic>{};
  switch (sel.mode) {
    case RegionMode.all:
      qp['all'] = '1';
      break;
    case RegionMode.majors:
      qp['scope'] = 'federal';
      break;
    case RegionMode.region:
      qp['region'] = sel.slug;
      break;
    case RegionMode.myRegion:
      if (city.isNotEmpty) qp['city'] = city;
      break;
  }

  final res = await _racesDio.get<Map<String, dynamic>>('/races', queryParameters: qp);
  final items = (res.data?['races'] as List? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(RaceEvent.fromJson)
      .toList();
  return RacesFeed(items: items, region: res.data?['region']?.toString() ?? '');
});

/// Список регионов с забегами (для пикера).
final raceRegionsProvider = FutureProvider.autoDispose<List<RaceRegion>>((ref) async {
  final res = await _racesDio.get<Map<String, dynamic>>('/races/regions');
  return (res.data?['regions'] as List? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(RaceRegion.fromJson)
      .toList();
});
