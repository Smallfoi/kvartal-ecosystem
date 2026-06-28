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
    var cat = p.categoryId || ""; // для фильтра каталога
    var catLabel = p.categoryLabel || p.brand || "STAW";
    var sizes = Array.isArray(p.sizes) && p.sizes.length ? p.sizes : ["S", "M", "L", "XL"];
    var colors = Array.isArray(p.colors) && p.colors.length ? p.colors : ["#2b2f36", "#8a93a3"];
    var stock = p.inStock === false ? "Скоро в продаже" : "В наличии";
    var stockCls = p.inStock === false ? " product-stock--soon" : "";
    var colorDots = colors
      .map(function (c) { return '<i style="--c:' + esc(c) + '"></i>'; })
      .join("");
    var sizeChips = sizes
      .map(function (s) { return "<span>" + esc(s) + "</span>"; })
      .join("");
    var desc = p.description || "";
    return (
      '<article class="product-card reveal" data-category="' + esc(cat) + '"' +
      ' data-name="' + esc(p.name) + '" data-price="' + Number(p.price) + '"' +
      ' data-cat="' + esc(catLabel) + '" data-img="' + esc(img) + '"' +
      ' data-sizes="' + esc(sizes.join(",")) + '" data-colors="' + esc(colors.join(",")) + '"' +
      ' data-stock="' + esc(stock) + '" data-desc="' + esc(desc) + '">' +
      '<div class="product-media" data-quick-view tabindex="0" role="button" aria-label="Подробнее: ' +
      esc(p.name) + '">' +
      (img ? '<img src="' + esc(img) + '" alt="' + esc(p.name) + '" loading="lazy" />' : "") +
      "</div>" +
      '<div class="product-info">' +
      '<p class="product-cat">' + esc(catLabel) + "</p>" +
      "<h3>" + esc(p.name) + "</h3>" +
      '<div class="product-colors" aria-hidden="true">' + colorDots + "</div>" +
      '<div class="product-sizes" aria-hidden="true">' + sizeChips + "</div>" +
      '<div class="product-bottom">' +
      '<span class="product-price">' + priceFmt(p.price) + "</span>" +
      '<span class="product-stock' + stockCls + '">' + esc(stock) + "</span>" +
      "</div>" +
      '<button class="product-add" type="button" data-add-cart="' + esc(p.name) +
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
    // Товары пришли из API → подтягиваем категории и перестраиваем фильтры под них.
    loadCategories();
  }

  // Динамические фильтры из /categories (id товара == categoryId фильтра).
  function renderFilters(categories) {
    var wrap = document.querySelector("[data-filters]");
    if (!wrap || !Array.isArray(categories) || categories.length === 0) return;
    var html = '<button class="filter is-active" type="button" data-filter="all">Все</button>';
    categories.forEach(function (c) {
      if (!c || !c.id || c.id === "all") return;
      html +=
        '<button class="filter" type="button" data-filter="' +
        esc(c.id) +
        '">' +
        esc(c.name || c.id) +
        "</button>";
    });
    wrap.innerHTML = html;
  }

  function loadCategories() {
    fetch(API + "/categories")
      .then(function (r) { return r.ok ? r.json() : Promise.reject(); })
      .then(renderFilters)
      .catch(function () {});
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
