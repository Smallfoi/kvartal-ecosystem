// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// Web-реализация моста: читаем ?edit=1 и шлём порядок родителю через postMessage.
// Сообщение — JSON-строкой (родитель-конструктор её распарсит), формат совпадает
// с editor.js сайта: {source:'staw-editor', type:'reorder', platform:'app', order:[...]}.
import 'dart:convert';
import 'dart:html' as html;

bool get consoleEditMode => Uri.base.queryParameters['edit'] == '1';

void postReorder(List<String> productIds) {
  html.window.parent?.postMessage(
    jsonEncode({
      'source': 'staw-editor',
      'type': 'reorder',
      'platform': 'app',
      'order': productIds,
    }),
    '*',
  );
}
