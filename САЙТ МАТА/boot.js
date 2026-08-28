/**
 * Ранний старт контента: убирает «мелькание старой версии» при загрузке.
 *
 * В чём была проблема. Тексты, фото и настройки блоков живут в базе, а в разметке
 * лежат исходные значения — те, с которыми страницу верстали. Порядок был такой:
 * браузер рисует разметку → в конце страницы грузится content.js → он спрашивает
 * сервер → приходят правки владельца → страница перерисовывается. Между первым и
 * последним шагом видно исходную вёрстку: заголовок в другом месте, старые надписи.
 * На быстром соединении это доля секунды, на медленном — заметно, а при частых
 * перезагрузках бросается в глаза.
 *
 * Что делает этот файл (подключается ПЕРВЫМ, в <head>):
 *   1. сразу стартует запрос к серверу — не дожидаясь конца страницы;
 *   2. достаёт прошлый ответ из памяти браузера, чтобы применить его мгновенно;
 *   3. если прошлый ответ есть — прячет ровно те элементы, у которых он что-то
 *      меняет, до момента применения. Тогда «старый» текст не показывается вовсе.
 *      Страховка: если правки почему-то не пришли, элементы всё равно покажутся
 *      через 2,5 секунды — пустой страницы не будет.
 */
(function () {
  "use strict";
  var CACHE_KEY = "staw-content-cache";

  var host = location.hostname;
  var isDev = host === "localhost" || host === "127.0.0.1" || host === "";
  var API =
    (typeof window !== "undefined" && window.STAW_API_BASE) ||
    (isDev ? "http://127.0.0.1:8000/v1" : "https://api.mata-club.ru/v1");

  // 1. Запрос стартует прямо сейчас. content.js подхватит этот же промис.
  try {
    window.__stawEarly = fetch(API + "/site/content")
      .then(function (r) { return r.ok ? r.json() : null; })
      .catch(function () { return null; });
  } catch (e) {}

  // 2. Прошлый ответ — применим его до сети.
  var cache = null;
  try {
    var raw = localStorage.getItem(CACHE_KEY);
    if (raw) cache = JSON.parse(raw);
  } catch (e) {}
  window.__stawCache = cache;

  if (!cache) return;   // первый визит: прятать нечего, показываем вёрстку как есть

  // 3. Прячем только те элементы, которые правка всё равно изменит.
  var keys = Object.keys(cache.items || cache || {});
  var targets = {};
  for (var i = 0; i < keys.length; i++) {
    var k = keys[i];
    var dot = k.indexOf(".");
    // Служебные ключи вида «width.<цель>» указывают на ту же цель, что и текст.
    var target = dot > 0 && /^(width|minh|pos|talign|fontsize|font|color|shadow|anim|hidden|size|align|order|focal|fit)$/.test(k.slice(0, dot))
      ? k.slice(dot + 1)
      : k;
    if (/^[\w.-]+$/.test(target)) targets[target] = 1;
  }
  var sel = Object.keys(targets).map(function (t) {
    return '[data-edit="' + t + '"]';
  });
  if (!sel.length) return;

  var style = document.createElement("style");
  style.id = "staw-fouc";
  style.textContent = sel.join(",") + "{visibility:hidden}";
  (document.head || document.documentElement).appendChild(style);

  // Страховка от пустой страницы: снимаем прятание, даже если правки не пришли.
  window.__stawFoucTimer = setTimeout(function () {
    var s = document.getElementById("staw-fouc");
    if (s) s.remove();
  }, 2500);
})();
