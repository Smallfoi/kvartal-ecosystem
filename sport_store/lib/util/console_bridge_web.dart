// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// Web-реализация моста: шлём события правки родителю через postMessage и слушаем
// черновик. Сообщение — JSON-строкой (родитель-конструктор её распарсит), формат
// совпадает с editor.js сайта: {source:'staw-editor', type:'...', ...}.
import 'dart:convert';
import 'dart:html' as html;

void _send(Map<String, dynamic> msg) {
  msg['source'] = 'staw-editor';
  html.window.parent?.postMessage(jsonEncode(msg), '*');
}

void postReorder(List<String> productIds) {
  _send({'type': 'reorder', 'platform': 'app', 'order': productIds});
}

void postEditContent(String key, String value,
    {String color = '', bool hasColor = false}) {
  _send({
    'type': 'editContent',
    'key': key,
    'value': value,
    'color': color,
    'hasColor': hasColor,
  });
}

void postEditImage(String key, String url,
    {String focal = '', String fit = 'cover', double aspect = 0}) {
  _send({
    'type': 'editImage',
    'key': key,
    'url': url,
    'focal': focal,
    'fit': fit,
    'aspect': aspect,
  });
}

void postEditBg(String key,
    {String img = '', String vid = '', String off = '', String focal = '', String fit = 'cover'}) {
  _send({
    'type': 'editBg',
    'key': key,
    'img': img,
    'vid': vid,
    'off': off,
    'focal': focal,
    'fit': fit,
  });
}

void postReady() {
  _send({'type': 'ready', 'platform': 'app'});
}

void _listen(String type, void Function(Map msg) handle) {
  html.window.onMessage.listen((event) {
    try {
      final data = event.data;
      final msg = data is String ? jsonDecode(data) : data;
      if (msg is Map &&
          msg['source'] == 'staw-console' &&
          msg['type'] == type &&
          msg['key'] is String) {
        handle(msg);
      }
    } catch (_) {
      // чужое/некорректное сообщение — игнорируем
    }
  });
}

void onConsoleSetContent(void Function(String key, String value) cb) {
  _listen('setContent', (msg) => cb(msg['key'] as String, (msg['value'] ?? '').toString()));
}

void onConsoleSetImage(void Function(String key, String url) cb) {
  _listen('setImage', (msg) => cb(msg['key'] as String, (msg['url'] ?? '').toString()));
}
