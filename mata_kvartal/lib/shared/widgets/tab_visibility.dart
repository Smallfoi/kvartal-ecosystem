import 'package:flutter/widgets.dart';

/// Обновление данных при возврате на вкладку.
///
/// Вкладки таб-бара больше не пересоздаются при переключении: у каждой своя
/// ветка навигации, экран остаётся живым (см. `app_router.dart`). Это и вылечило
/// «после карты соседний экран пустой» — сносить тяжёлый экран в том же кадре
/// больше не нужно. Но `initState` теперь срабатывает один раз за запуск, а
/// раньше именно он тянул свежие данные при каждом заходе на вкладку.
///
/// Примесь возвращает это поведение честным способом: [onTabShown] вызывается
/// каждый раз, когда вкладка снова становится видимой (первый показ не считается —
/// там данные тянет `initState`). Признак видимости — [TickerMode]: невидимую
/// ветку go_router оборачивает в `TickerMode(enabled: false)`, поэтому отдельный
/// «наблюдатель видимости» не нужен.
mixin TabVisibility<T extends StatefulWidget> on State<T> {
  bool? _visible;

  /// Вкладку снова показали — самое время обновить данные.
  void onTabShown();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.of(context);
    if (visible == _visible) return;
    final first = _visible == null;
    _visible = visible;
    if (visible && !first) onTabShown();
  }

  /// Видна ли вкладка прямо сейчас — для фоновой работы (таймеры, опрос сети),
  /// которую на скрытой вкладке крутить незачем.
  bool get isTabVisible => _visible ?? true;
}
