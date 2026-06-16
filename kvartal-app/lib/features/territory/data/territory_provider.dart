import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/api_config.dart';
import '../../auth/data/auth_provider.dart';

/// Отношение территории к текущему пользователю (приходит с сервера).
enum TerritoryRel { mine, club, enemy }

TerritoryRel _relFromString(String? s) {
  switch (s) {
    case 'mine':
      return TerritoryRel.mine;
    case 'club':
      return TerritoryRel.club;
    default:
      return TerritoryRel.enemy;
  }
}

/// Реальная территория с PostGIS-бэка (D-09). Контур(ы) уже сглажены сервером.
class ServerTerritory {
  final String ownerId;
  final String? clubId;
  final TerritoryRel rel;

  /// Внешние кольца полигонов (для MultiPolygon — по кольцу на полигон).
  final List<List<LatLng>> rings;

  const ServerTerritory({
    required this.ownerId,
    required this.clubId,
    required this.rel,
    required this.rings,
  });

  factory ServerTerritory.fromJson(Map<String, dynamic> json) {
    final geojson = json['geojson'];
    return ServerTerritory(
      ownerId: json['ownerId']?.toString() ?? '',
      clubId: json['clubId']?.toString(),
      rel: _relFromString(json['rel']?.toString()),
      rings: geojson is Map<String, dynamic>
          ? ringsFromGeoJson(geojson)
          : const [],
    );
  }
}

/// Разбор GeoJSON (Polygon / MultiPolygon) во внешние кольца LatLng.
/// Координаты GeoJSON идут как [lng, lat] — переворачиваем в LatLng(lat, lng).
List<List<LatLng>> ringsFromGeoJson(Map<String, dynamic> geojson) {
  final type = geojson['type']?.toString();
  final coords = geojson['coordinates'];
  final rings = <List<LatLng>>[];
  if (type == 'Polygon' && coords is List && coords.isNotEmpty) {
    rings.add(_ring(coords.first));
  } else if (type == 'MultiPolygon' && coords is List) {
    for (final polygon in coords) {
      if (polygon is List && polygon.isNotEmpty) {
        rings.add(_ring(polygon.first));
      }
    }
  }
  return rings.where((r) => r.length >= 3).toList();
}

List<LatLng> _ring(dynamic ring) {
  final out = <LatLng>[];
  if (ring is List) {
    for (final point in ring) {
      if (point is List && point.length >= 2) {
        out.add(
          LatLng((point[1] as num).toDouble(), (point[0] as num).toDouble()),
        );
      }
    }
  }
  return out;
}

class TerritoryState {
  final List<ServerTerritory> territories;
  final bool isLoading;
  final bool isCapturing;
  final String? error;
  final String? message;

  /// Площадь моей территории после последнего захвата, м².
  final double? lastAreaM2;

  const TerritoryState({
    this.territories = const [],
    this.isLoading = false,
    this.isCapturing = false,
    this.error,
    this.message,
    this.lastAreaM2,
  });

  TerritoryState copyWith({
    List<ServerTerritory>? territories,
    bool? isLoading,
    bool? isCapturing,
    String? error,
    String? message,
    double? lastAreaM2,
    bool clearError = false,
    bool clearMessage = false,
  }) => TerritoryState(
    territories: territories ?? this.territories,
    isLoading: isLoading ?? this.isLoading,
    isCapturing: isCapturing ?? this.isCapturing,
    error: clearError ? null : error ?? this.error,
    message: clearMessage ? null : message ?? this.message,
    lastAreaM2: lastAreaM2 ?? this.lastAreaM2,
  );
}

class TerritoryNotifier extends StateNotifier<TerritoryState> {
  final Ref ref;
  TerritoryNotifier(this.ref) : super(const TerritoryState());

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json', 'Connection': 'close'},
    ),
  );

  String? get _token {
    final token = ref.read(authProvider).token;
    return (token == null || token.isEmpty) ? null : token;
  }

  /// Загрузить территории в видимой области карты.
  /// bbox порядок — minLng, minLat, maxLng, maxLat (как ждёт бэк).
  Future<void> loadBbox({
    required double minLng,
    required double minLat,
    required double maxLng,
    required double maxLat,
  }) async {
    final token = _token;
    if (token == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/territories',
        queryParameters: {'bbox': '$minLng,$minLat,$maxLng,$maxLat'},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final list = (response.data?['territories'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ServerTerritory.fromJson)
          .where((t) => t.rings.isNotEmpty)
          .toList();
      state = state.copyWith(
        territories: list,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _errorText(e));
    }
  }

  /// Отправить замкнутый маршрут на сервер для захвата территории.
  /// Возвращает площадь моей территории (м²) или null при ошибке.
  Future<double?> capture(List<LatLng> route) async {
    final token = _token;
    if (token == null || route.length < 3) return null;
    state = state.copyWith(isCapturing: true, clearError: true, clearMessage: true);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/territories/capture',
        data: {
          'points': [
            for (final p in route) [p.latitude, p.longitude],
          ],
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data ?? const <String, dynamic>{};
      final area = (data['areaM2'] as num?)?.toDouble();
      final geojson = data['geojson'];
      // Сразу показываем свою обновлённую территорию, не дожидаясь bbox-загрузки.
      if (geojson is Map<String, dynamic>) {
        final mine = ServerTerritory(
          ownerId: 'me',
          clubId: null,
          rel: TerritoryRel.mine,
          rings: ringsFromGeoJson(geojson),
        );
        final others = state.territories
            .where((t) => t.rel != TerritoryRel.mine)
            .toList();
        state = state.copyWith(
          territories: mine.rings.isEmpty ? others : [...others, mine],
          isCapturing: false,
          lastAreaM2: area,
          message: area != null
              ? 'Территория захвачена: ${_areaLabel(area)}'
              : 'Территория захвачена',
          clearError: true,
        );
      } else {
        state = state.copyWith(isCapturing: false, lastAreaM2: area);
      }
      return area;
    } catch (e) {
      state = state.copyWith(isCapturing: false, error: _errorText(e));
      return null;
    }
  }

  void clearMessage() => state = state.copyWith(clearMessage: true, clearError: true);

  /// Сброс при смене аккаунта — чужие/старые территории больше не наши.
  void reset() => state = const TerritoryState();

  String _arealessFallback() => 'Не удалось обработать территорию.';

  String _errorText(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Нет связи с сервером территорий. Проверь backend и USB/Wi-Fi.';
      }
    }
    return _arealessFallback();
  }
}

String _areaLabel(double areaM2) {
  if (areaM2 >= 1000000) {
    return '${(areaM2 / 1000000).toStringAsFixed(2)} км²';
  }
  if (areaM2 >= 10000) {
    return '${(areaM2 / 10000).toStringAsFixed(2)} га';
  }
  return '${areaM2.round()} м²';
}

final territoryProvider =
    StateNotifierProvider<TerritoryNotifier, TerritoryState>((ref) {
      final notifier = TerritoryNotifier(ref);
      // При смене аккаунта старые территории больше не наши — сбрасываем.
      ref.listen<AuthState>(authProvider, (prev, next) {
        if (next.token != prev?.token) {
          notifier.reset();
        }
      });
      return notifier;
    });
