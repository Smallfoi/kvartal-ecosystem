/**
 * Динамическая витрина: подтягивает товары из общего backend и рисует карточки
 * в существующую сетку каталога (вёрстку/классы сайта не меняем — просто наполняем).
 * Если открыть сайт с ?preview=1 — показываются и черновики (для админ-превью).
 * При недоступном API остаются статичные карточки из index.html (фолбэк).
 */
(function () {
  "use strict";

  var params = new URLSearchParams(location.search);
  var PREVIEW = params.get("preview") === "1";

  // База API — как в ecosystem.js: dev (localhost) → :8000, иначе прод/override.
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
  function priceFmt(v) {
    return new Intl.NumberFormat("ru-RU").format(v) + " ₽";
  }
  function imgUrl(p) {
    var u = p.imageUrl || (p.imageUrls && p.imageUrls[0]) || "";
    if (!u) return "";
    if (u.indexOf("http") === 0) return u;
    return u.charAt(0) === "/" ? ORIGIN + u : ORIGIN + "/" + u;
  }

  function cardHtml(p) {
    var img = imgUrl(p);
    var cat = p.categoryId || "";
    return (
      '<article class="product-card reveal" data-category="' + esc(cat) + '">' +
      (img ? '<img src="' + esc(img) + '" alt="' + esc(p.name) + '" loading="lazy" />' : "") +
      '<div class="product-info">' +
      "<p>" + esc(p.brand || "STAW") + "</p>" +
      "<h3>" + esc(p.name) + "</h3>" +
      "<span>" + priceFmt(p.price) + "</span>" +
      (p.description ? "<small>" + esc(p.description) + "</small>" : "") +
      '<button type="button" data-add-cart="' + esc(p.name) +
      '" data-price="' + Number(p.price) + '">В корзину</button>' +
      "</div></article>"
    );
  }

  function render(products) {
    var grid = document.querySelector("[data-product-grid]");
    if (!grid || !Array.isArray(products) || products.length === 0) return;
    grid.innerHTML = products.map(cardHtml).join("");
    // Переинициализируем интеракции (фильтр/корзина/анимации) для новых карточек.
    if (window.STAW && typeof window.STAW.onCatalogRendered === "function") {
      window.STAW.onCatalogRendered();
    }
  }

  function load() {
    fetch(API + "/products" + (PREVIEW ? "?preview=1" : ""))
      .then(function (r) { return r.ok ? r.json() : Promise.reject(); })
      .then(render)
      .catch(function () { /* офлайн/нет API — оставляем статичные карточки */ });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", load);
  } else {
    load();
  }
})();
