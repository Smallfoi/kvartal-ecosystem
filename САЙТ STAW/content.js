/**
 * Мини-CMS: сайт читает редактируемый контент из общего бэкенда (/site/content)
 * и подставляет его в элементы с data-edit (текст) и data-edit-img (фото).
 * Тексты/фото задаёт владелец в «Конструкторе». Если контента нет — остаётся то,
 * что в HTML (значения по умолчанию). Офлайн/нет API — сайт не ломается.
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

  function mediaUrl(u) {
    if (!u) return "";
    return u.indexOf("http") === 0 ? u : ORIGIN + u;
  }

  function apply(content) {
    if (!content) return;
    Object.keys(content).forEach(function (key) {
      var c = content[key] || {};
      if (c.value) {
        document.querySelectorAll('[data-edit="' + key + '"]').forEach(function (el) {
          el.textContent = c.value;
        });
      }
      if (c.imageUrl) {
        var url = mediaUrl(c.imageUrl);
        document.querySelectorAll('[data-edit-img="' + key + '"]').forEach(function (el) {
          if (el.tagName === "IMG") el.src = url;
          else el.style.backgroundImage = "url('" + url + "')";
        });
      }
    });
  }

  fetch(API + "/site/content")
    .then(function (r) { return r.ok ? r.json() : Promise.reject(); })
    .then(apply)
    .catch(function () { /* нет API — остаются значения по умолчанию из HTML */ });
})();
