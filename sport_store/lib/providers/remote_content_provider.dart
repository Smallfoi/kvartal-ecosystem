import 'package:flutter/foundation.dart';

import '../data/api/api_client.dart';
import '../data/api/api_config.dart';
import '../util/console_bridge.dart';

/// Редактируемый контент приложения из общего backend (`/site/content`, ключи `app.*`).
///
/// Работает так же, как мини-CMS сайта: владелец правит в «Конструкторе»
/// (вкладка «Приложение»), значение сохраняется в `SiteContent` под ключом
/// `app.<...>`, а приложение показывает его вместо фолбэка. Ключи `app.*` не
/// пересекаются с сайтом (у сайта — свои ключи), одно хранилище на всё.
///
/// Поддерживает как на сайте: **текст** (`app.<k>`), **цвет текста**
/// (`color.app.<k>`), **фото** (`imageUrl` ключа + `focal.`/`fit.`).
///
/// - **Прод (реальный app):** просто подтягивает опубликованное; нет значения —
///   остаётся фолбэк (текущий текст/ассет в коде). Ничего не ломает.
/// - **Конструктор (web-сборка, CONSOLE_EDIT=1):** элементы кликабельны
///   (см. `RemoteText`/`RemoteImage`); черновик применяется поверх (setContent/setImage).
class RemoteContentProvider extends ChangeNotifier {
  final ApiClient? _api;
  final Map<String, String> _content = {}; // тексты + служебные (color./focal./fit.)
  final Map<String, String> _images = {}; // абсолютные URL фото по ключу

  RemoteContentProvider(this._api) {
    _init();
  }

  /// Текст по ключу или фолбэк, если значения нет/оно пустое.
  String text(String key, String fallback) {
    final v = _content[key];
    return (v != null && v.isNotEmpty) ? v : fallback;
  }

  /// Цвет текста (hex `#rrggbb`) по ключу или '' — из ключа `color.<key>`.
  String color(String key) => _content['color.$key'] ?? '';

  /// Фокус-область фото ("x% y%") — ключ `focal.<key>`.
  String focal(String key) => _content['focal.$key'] ?? '';

  /// Подгон фото ("contain"/"") — ключ `fit.<key>`.
  String fit(String key) => _content['fit.$key'] ?? '';

  /// Абсолютный URL фото по ключу или '' (фолбэк-ассет решает виджет).
  String imageUrl(String key) => _images[key] ?? '';

  /// Сырое значение по полному ключу или '' (для служебных bg-полей:
  /// `bgvid.<k>`/`bgoff.<k>`/`bgfocal.<k>`/`bgfit.<k>`). Фото фона — `imageUrl('bg.<k>')`.
  String value(String key) => _content[key] ?? '';

  Future<void> _init() async {
    await _load(); // сначала опубликованное как база
    if (consoleEditMode) {
      onConsoleSetContent(applyDraft); // текст/цвет из конструктора
      onConsoleSetImage(applyImageDraft); // фото из конструктора
      postReady(); // сигнал родителю: готовы принимать черновик
    }
  }

  Future<void> _load() async {
    final api = _api;
    if (api == null) return;
    try {
      final data = await api.get('/site/content');
      if (data is Map) {
        data.forEach((k, v) {
          if (k is! String || v is! Map) return;
          if (v['value'] is String) {
            final s = v['value'] as String;
            if (s.isNotEmpty) _content[k] = s;
          }
          if (v['imageUrl'] is String) {
            final u = v['imageUrl'] as String;
            if (u.isNotEmpty) _images[k] = ApiConfig.resolveMedia(u);
          }
        });
        notifyListeners();
      }
    } catch (_) {
      // офлайн / нет API — остаются фолбэки из кода
    }
  }

  /// Применить черновой текст/цвет из конструктора (пустое = снять правку → фолбэк).
  void applyDraft(String key, String value) {
    if (value.isEmpty) {
      _content.remove(key);
    } else {
      _content[key] = value;
    }
    notifyListeners();
  }

  /// Применить черновое фото из конструктора (setImage {key,url}); пустое = снять.
  void applyImageDraft(String key, String url) {
    if (url.isEmpty) {
      _images.remove(key);
    } else {
      // dataURL (свежая незагруженная картинка) оставляем как есть; иначе — абсолютный.
      _images[key] = url.startsWith('data:') ? url : ApiConfig.resolveMedia(url);
    }
    notifyListeners();
  }
}
