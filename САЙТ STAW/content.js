/**
 * Мини-CMS: сайт читает редактируемый контент из общего бэкенда (/site/content)
 * и подставляет его в элементы:
 *   - data-edit       → текст (textContent);
 *   - data-edit-img   → фото (img.src / background);
 *   - order.<group>   → порядок карточек в контейнере [data-sortable="<group>"];
 *   - hidden.<key>    → скрытые блоки [data-hideable="<key>"] (значение "1").
 * Всё это задаёт владелец в «Конструкторе». Если контента нет — остаётся то,
 * что в HTML (значения по умолчанию). Офлайн/нет API — сайт не ломается.
 *
 * В режиме правки (?edit=1, внутри «Конструктора») скрытые блоки НЕ убираются
 * из DOM, а показываются приглушённо (класс staw-cms-hidden) — чтобы владелец мог
 * вернуть их. Порядок/тексты/фото применяются как база, поверх которой editor.js
 * накладывает черновик. Чтобы черновик не был затёрт, после применения шлём
 * событие staw-content-applied — editor.js ждёт его перед показом черновика.
 */
(function () {
  "use strict";
  var host = location.hostname;
  var isDev = host === "localhost" || host === "127.0.0.1" || host === "";
  var PROD_API = "https://api.staw.ru/v1";
  var API =
    (typeof window !== "undefined" && window.STAW_API_BASE) ||
    (isDev ? "http://127.0.0.1:8000/v1" : PROD_API);
  var ORIGIN = API.replace(/\/v1\/?$/, "");
  var EDIT = new URLSearchParams(location.search).get("edit") === "1";

  function mediaUrl(u) {
    if (!u) return "";
    return u.indexOf("http") === 0 ? u : ORIGIN + u;
  }

  // Ключи/идентификаторы — только наши (буквы/цифры/._-). Защита от инъекции в селектор.
  function safeId(s) { return typeof s === "string" && /^[\w.-]+$/.test(s); }

  // Переупорядочить прямых детей контейнера по списку data-sid (отсутствующие — в конце).
  function reorderChildren(container, order) {
    if (!container || !Array.isArray(order)) return;
    var byId = {};
    var kids = [].slice.call(container.children);
    kids.forEach(function (ch) {
      var s = ch.getAttribute && ch.getAttribute("data-sid");
      if (s) byId[s] = ch;
    });
    order.forEach(function (sid) {
      if (byId[sid]) { container.appendChild(byId[sid]); delete byId[sid]; }
    });
    // Не упомянутые в порядке — оставляем в конце, сохраняя исходную относительную последовательность.
    kids.forEach(function (ch) {
      var s = ch.getAttribute && ch.getAttribute("data-sid");
      if (s && byId[s]) container.appendChild(ch);
    });
  }

  function applyOrder(group, val) {
    if (!safeId(group) || !val) return;
    var order;
    try { order = JSON.parse(val); } catch (e) { return; }
    if (!Array.isArray(order)) return;
    reorderChildren(document.querySelector('[data-sortable="' + group + '"]'), order);
  }

  function applyHidden(key, val) {
    if (!safeId(key)) return;
    var hide = val === "1";
    document.querySelectorAll('[data-hideable="' + key + '"]').forEach(function (el) {
      if (EDIT) {
        el.classList.toggle("staw-cms-hidden", hide); // в конструкторе — приглушаем, не удаляем
        el.style.display = "";
      } else {
        el.style.display = hide ? "none" : "";
      }
    });
  }

  function apply(content) {
    if (!content) return;
    Object.keys(content).forEach(function (key) {
      try {
        var c = content[key] || {};
        if (key.indexOf("order.") === 0) { applyOrder(key.slice(6), c.value); return; }
        if (key.indexOf("hidden.") === 0) { applyHidden(key.slice(7), c.value); return; }
        if (c.value && safeId(key)) {
          document.querySelectorAll('[data-edit="' + key + '"]').forEach(function (el) {
            el.textContent = c.value;
          });
        }
        if (c.imageUrl && safeId(key)) {
          var url = mediaUrl(c.imageUrl);
          document.querySelectorAll('[data-edit-img="' + key + '"]').forEach(function (el) {
            if (el.tagName === "IMG") el.src = url;
            else el.style.backgroundImage = "url('" + url + "')";
          });
        }
      } catch (e) { /* один плохой ключ не должен ломать остальные */ }
    });
  }

  // После применения базового контента — сигналим editor.js (он ждёт, чтобы наложить черновик).
  function done() {
    try { if (EDIT) window.dispatchEvent(new Event("staw-content-applied")); } catch (e) {}
  }

  fetch(API + "/site/content")
    .then(function (r) { return r.ok ? r.json() : Promise.reject(); })
    .then(apply)
    .then(done)
    .catch(function () { done(); /* нет API — остаются значения по умолчанию из HTML */ });
})();
