// Мост «Конструктор» ↔ приложение. Работает только в web-сборке, открытой в
// iframe админки (?edit=1). На мобильном — no-op (условный импорт).
//
// Приложение нельзя редактировать «снаружи» как HTML-сайт (это Flutter/canvas),
// поэтому перетаскивание живёт ВНУТРИ приложения, а новый порядок отправляется
// родителю-конструктору тем же сообщением, что шлёт editor.js сайта. Конструктор
// копит это в черновик и публикует на бэкенд по кнопке (с подтверждением).
import 'console_bridge_stub.dart'
    if (dart.library.html) 'console_bridge_web.dart' as impl;

/// true — приложение открыто в конструкторе в режиме правки (web + ?edit=1).
bool get consoleEditMode => impl.consoleEditMode;

/// Отправить новый порядок товаров (площадка app) родителю-конструктору.
void postReorder(List<String> productIds) => impl.postReorder(productIds);
