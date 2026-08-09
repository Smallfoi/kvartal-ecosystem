// Мост «Конструктор» ↔ приложение. Работает только в web-сборке, открытой в
// iframe админки (?edit=1). На мобильном — no-op (условный импорт).
//
// Приложение нельзя редактировать «снаружи» как HTML-сайт (это Flutter/canvas),
// поэтому правка живёт ВНУТРИ приложения, а событие отправляется родителю-
// конструктору тем же сообщением, что шлёт editor.js сайта. Конструктор копит это
// в черновик и публикует на бэкенд по кнопке (с подтверждением).
import 'package:flutter/foundation.dart';

import 'console_bridge_stub.dart'
    if (dart.library.html) 'console_bridge_web.dart' as impl;

/// Режим правки конструктора. Задаётся при сборке web-превью для конструктора:
/// flutter build web --dart-define=CONSOLE_EDIT=1. В обычном APK флага нет → false.
/// ВАЖНО: сравниваем строку, а НЕ bool.fromEnvironment — тот принимает только
/// "true"/"false", а "1" считает за default (false). (URL ?edit=1 не годится:
/// go_router на старте убирает query из адреса.)
const bool consoleEditMode = String.fromEnvironment('CONSOLE_EDIT') == '1';

/// РАНТАЙМ-режим правки: изначально = сборочный флаг, но конструктор может
/// переключать его на лету (кнопка «Просмотр ⇄ Правка» на вкладке приложения).
/// В «Просмотре» перехват тапов выключается → приложением можно свободно листать
/// (онбординг, «Далее» и т.п.). Виджеты-обёртки слушают этот notifier.
final ValueNotifier<bool> consoleEditNotifier = ValueNotifier<bool>(consoleEditMode);

/// Подписка на команду конструктора «переключить режим правки» (setEditMode {value}).
void onConsoleSetEditMode(void Function(bool on) cb) => impl.onConsoleSetEditMode(cb);

/// Отправить новый порядок товаров (площадка app) родителю-конструктору.
void postReorder(List<String> productIds) => impl.postReorder(productIds);

/// Клик по редактируемому тексту → правка в конструкторе (как editContent сайта).
/// [color]/[hasColor] — текущий цвет текста, чтобы модалка предвыбрала его.
void postEditContent(String key, String value,
        {String color = '', bool hasColor = false}) =>
    impl.postEditContent(key, value, color: color, hasColor: hasColor);

/// Клик по редактируемому фото → та же модалка фото конструктора (editImage сайта).
void postEditImage(String key, String url,
        {String focal = '', String fit = 'cover', double aspect = 0}) =>
    impl.postEditImage(key, url, focal: focal, fit: fit, aspect: aspect);

/// Клик по кнопке «Фон» блока/экрана → та же модалка фона конструктора (editBg сайта).
void postEditBg(String key,
        {String img = '', String vid = '', String off = '', String focal = '', String fit = 'cover'}) =>
    impl.postEditBg(key, img: img, vid: vid, off: off, focal: focal, fit: fit);

/// Сигнал родителю-конструктору: приложение готово принимать черновик.
void postReady() => impl.postReady();

/// Подписка на черновые правки текста/цвета из конструктора (setContent {key,value}).
void onConsoleSetContent(void Function(String key, String value) cb) =>
    impl.onConsoleSetContent(cb);

/// Подписка на черновые правки фото из конструктора (setImage {key,url}).
void onConsoleSetImage(void Function(String key, String url) cb) =>
    impl.onConsoleSetImage(cb);
