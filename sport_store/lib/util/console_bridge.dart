// Мост «Конструктор» ↔ приложение. Работает только в web-сборке, открытой в
// iframe админки (?edit=1). На мобильном — no-op (условный импорт).
//
// Приложение нельзя редактировать «снаружи» как HTML-сайт (это Flutter/canvas),
// поэтому перетаскивание живёт ВНУТРИ приложения, а новый порядок отправляется
// родителю-конструктору тем же сообщением, что шлёт editor.js сайта. Конструктор
// копит это в черновик и публикует на бэкенд по кнопке (с подтверждением).
import 'console_bridge_stub.dart'
    if (dart.library.html) 'console_bridge_web.dart' as impl;

/// Режим правки конструктора. Задаётся при сборке web-превью для конструктора:
/// flutter build web --dart-define=CONSOLE_EDIT=1. В обычном APK флага нет → false.
/// ВАЖНО: сравниваем строку, а НЕ bool.fromEnvironment — тот принимает только
/// "true"/"false", а "1" считает за default (false). (URL ?edit=1 не годится:
/// go_router на старте убирает query из адреса.)
const bool consoleEditMode = String.fromEnvironment('CONSOLE_EDIT') == '1';

/// Отправить новый порядок товаров (площадка app) родителю-конструктору.
void postReorder(List<String> productIds) => impl.postReorder(productIds);
