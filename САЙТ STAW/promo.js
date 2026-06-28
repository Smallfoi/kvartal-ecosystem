/**
 * Промо-баннеры из общего backend (/banners) → стрип под hero.
 * Источник управления — админка (Catalog → Banner). При офлайн/недоступном API
 * секция остаётся скрытой (graceful), сайт не ломается.
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

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  // Адаптер путей медиа бэкенда: "assets/images/products/X.jpg" → ORIGIN/media/products/X.jpg.
  function media(u) {
    if (!u) return "";
    if (u.indexOf("http") === 0) return u;
    var m = u.match(/products\/([^/]+)$/);
    if (m) return ORIGIN + "/media/products/" + m[1];
    return u.charAt(0) === "/" ? ORIGIN + u : ORIGIN + "/" + u;
  }

  function render(banners) {
    var sec = document.querySelector("[data-promo]");
    var track = document.querySelector("[data-promo-track]");
    if (!sec || !track || !Array.isArray(banners) || banners.length === 0) return;

    track.innerHTML = banners
      .map(function (b) {
        var img = media(b.imageUrl);
        var title = String(b.title || "")
          .split("\n")
          .map(esc)
          .join("<br>");
        return (
          '<article class="promo-card"' +
          (img ? " style=\"--bg:url('" + img + "')\"" : "") +
          ">" +
          '<div class="promo-card-body">' +
          (b.subtitle ? '<p class="promo-sub">' + esc(b.subtitle) + "</p>" : "") +
          '<h3 class="promo-title">' + title + "</h3>" +
          (b.action ? '<span class="promo-cta">' + esc(b.action) + " →</span>" : "") +
          "</div></article>"
        );
      })
      .join("");
    sec.hidden = false;
  }

  function load() {
    fetch(API + "/banners")
      .then(function (r) {
        return r.ok ? r.json() : Promise.reject();
      })
      .then(render)
      .catch(function () {
        /* офлайн/нет API — секция остаётся скрытой */
      });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", load);
  } else {
    load();
  }
})();
