import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';

/// Правовой документ экосистемы STAW (соглашение, политика, согласие, оферта,
/// правила баллов/сообщества). Единый источник правды — backend: документы
/// редактируются в админ-панели, приложение всегда показывает актуальную
/// опубликованную версию (`GET /v1/legal/documents`). JSON парсим защитно.
class LegalDoc {
  final String type;
  final String title;
  final String version;
  final String body;
  final bool required;

  const LegalDoc({
    required this.type,
    required this.title,
    required this.version,
    required this.body,
    required this.required,
  });

  factory LegalDoc.fromJson(Map<String, dynamic> j) => LegalDoc(
        type: j['type']?.toString() ?? '',
        title: j['title']?.toString() ?? 'Документ',
        version: j['version']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        required: j['required'] == true,
      );
}

final _legalDio = Dio(BaseOptions(
  baseUrl: ApiConfig.baseUrl,
  connectTimeout: ApiConfig.connectTimeout,
  receiveTimeout: ApiConfig.receiveTimeout,
  headers: {'Content-Type': 'application/json', 'Connection': 'close'},
));

/// Опубликованные правовые документы (публичный эндпоинт — токен не нужен).
/// Меняешь текст в админке → приложение подтягивает новый при следующем открытии.
final legalDocumentsProvider =
    FutureProvider.autoDispose<List<LegalDoc>>((ref) async {
  final res = await _legalDio.get<List<dynamic>>('/legal/documents');
  return (res.data ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(LegalDoc.fromJson)
      .toList();
});
