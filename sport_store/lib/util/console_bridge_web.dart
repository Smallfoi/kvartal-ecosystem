// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// Web-реализация моста: читаем ?edit=1 и шлём порядок родителю через postMessage.
// Сообщение — JSON-строкой (родитель-конструктор её распарсит), формат совпадает
// с editor.js сайта: {source:'staw-editor', type:'reorder', platform:'app', order:[...]}.
import 'dart:convert';
import 'dart:html' as html;

void _send(Map<String, dynamic> msg) {
  msg['source'] = 'staw-editor';
  html.window.parent?.postMessage(jsonEncode(msg), '*');
}

void postReorder(List<String> productIds) {
  _send({'type': 'reorder', 'platform': 'app', 'order': productIds});
}

void postEditContent(String key, String value) {
  _send({'type': 'editContent', 'key': key, 'value': value});
}

void postReady() {
  _send({'type': 'ready', 'platform': 'app'});
}

void onConsoleSetContent(void Function(String key, String value) cb) {
  html.window.onMessage.listen((event) {
    try {
      final data = event.data;
      final msg = data is String ? jsonDecode(data) : data;
      if (msg is Map &&
          msg['source'] == 'staw-console' &&
          msg['type'] == 'setContent' &&
          msg['key'] is String) {
        cb(msg['key'] as String, (msg['value'] ?? '').toString());
      }
    } catch (_) {
      // чужое/некорректное сообщение — игнорируем
    }
  });
}
