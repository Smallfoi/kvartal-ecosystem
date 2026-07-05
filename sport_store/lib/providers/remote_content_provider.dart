import 'package:flutter/foundation.dart';

import '../data/api/api_client.dart';
import '../util/console_bridge.dart';

/// Редактируемые тексты приложения из общего backend (`/site/content`, ключи `app.*`).
///
/// Работает так же, как мини-CMS сайта: владелец правит текст в «Конструкторе»
/// (вкладка «Приложение»), значение сохраняется в `SiteContent` под ключом
/// `app.<...>`, а приложение показывает его вместо фолбэка. Ключи `app.*` не
/// пересекаются с сайтом (у сайта — свои ключи), одно хранилище на всё.
///
/// - **Прод (реальный app):** просто подтягивает опубликованные тексты; нет
///   значения/офлайн — остаётся фолбэк (текущий текст в коде). Ничего не ломает.
/// - **Конструктор (web-сборка, CONSOLE_EDIT=1):** тексты становятся кликабельными
///   (см. `RemoteText`); черновик из конструктора применяется поверх (setContent).
class RemoteContentProvider extends ChangeNotifier {
  final ApiClient? _api;
  final Map<String, String> _content = {};

  RemoteContentProvider(this._api) {
    _init();
  }

  /// Текст по ключу или фолбэк, если значения нет/оно пустое.
  String text(String key, String fallback) {
    final v = _content[key];
    return (v != null && v.isNotEmpty) ? v : fallback;
  }

  Future<void> _init() async {
    await _load(); // сначала опубликованное как база
    if (consoleEditMode) {
      onConsoleSetContent(applyDraft); // затем — черновик из конструктора
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
          if (k is String && v is Map && v['value'] is String) {
            final s = v['value'] as String;
            if (s.isNotEmpty) _content[k] = s;
          }
        });
        notifyListeners();
      }
    } catch (_) {
      // офлайн / нет API — остаются фолбэки из кода
    }
  }

  /// Применить черновое значение из конструктора (пустое = снять правку → фолбэк).
  void applyDraft(String key, String value) {
    if (value.isEmpty) {
      _content.remove(key);
    } else {
      _content[key] = value;
    }
    notifyListeners();
  }
}
