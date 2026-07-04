/**
 * Режим редактирования сайта для «Конструктора» (мини-CMS, headless-подход).
 * Активируется ТОЛЬКО при ?edit=1 — на живом сайте не работает и не мешает.
 *
 * Что умеет (всё копится в ЧЕРНОВИК у родителя-конструктора, публикуется по кнопке):
 *  - клик по [data-edit] / [data-edit-img] → правка текста / фото блока;
 *  - клик по товару (.product-card) → правка товара;
 *  - перетаскивание в ЛЮБОЙ группе [data-sortable] (карточки, фильтры, ссылки,
 *    фото, блоки) → новый порядок (order.<group>); товары — как раньше (reorder);
 *  - кнопка «Скрыть ✕ / Вернуть» на [data-hideable] → скрыть/показать блок (hidden.<key>).
 *
 * Кросс-домен: DOM iframe родителю недоступен, поэтому редактор ЖИВЁТ В САЙТЕ и
 * шлёт правки родителю через postMessage; сохраняет их авторизованно сам родитель.
 * content.js применяет ПУБЛИКОВАННЫЙ контент как базу, потом (по событию
 * staw-content-applied) мы шлём ready и родитель накладывает черновик — без гонки.
 */
(function () {
  "use strict";
  var params = new URLSearchParams(location.search);
  if (params.get("edit") !== "1") return; // только в режиме редактирования
  var PLATFORM = params.get("platform") === "app" ? "app" : "site";

  var css = document.createElement("style");
  css.textContent =
    "html.staw-edit [data-sid],html.staw-edit .product-card{cursor:grab;outline:2px dashed transparent;outline-offset:3px;transition:outline-color .12s}" +
    "html.staw-edit [data-sid]:hover,html.staw-edit .product-card:hover{outline-color:#0a84ff}" +
    "html.staw-edit .staw-dragging{opacity:.4}" +
    "html.staw-edit [data-edit],html.staw-edit [data-edit-img]{outline:2px dashed transparent;outline-offset:3px;cursor:pointer;transition:outline-color .12s}" +
    "html.staw-edit [data-edit]:hover,html.staw-edit [data-edit-img]:hover{outline-color:#0a84ff}" +
    "html.staw-edit [data-hideable]{position:relative}" +
    "html.staw-edit .staw-cms-hidden{opacity:.32;filter:grayscale(1)}" +
    "html.staw-edit .staw-del{position:absolute;top:6px;right:6px;z-index:30;border:0;border-radius:6px;" +
      "padding:3px 8px;font:600 11px/1 system-ui,-apple-system,sans-serif;background:rgba(17,24,39,.88);" +
      "color:#fff;cursor:pointer;box-shadow:0 1px 4px rgba(0,0,0,.3)}" +
    "html.staw-edit .product-add,html.staw-edit [data-quick-view]{pointer-events:none}";
  document.documentElement.appendChild(css);
  document.documentElement.classList.add("staw-edit");

  function send(msg) {
    msg.source = "staw-editor";
    if (window.parent !== window) window.parent.postMessage(msg, "*");
  }
  function draft(key, value) { send({ type: "draftContent", key: key, value: value }); }
  function safeId(s) { return typeof s === "string" && /^[\w.-]+$/.test(s); }

  var VOID_TAGS = { IMG: 1, INPUT: 1, BR: 1, HR: 1, AREA: 1, EMBED: 1 };

  // ── Перетаскивание: обобщённое (товары + любые группы [data-sortable]) ──
  var dragged = null, dragContainer = null;

  function sortItem(node) { return node && node.closest ? node.closest("[data-sid], .product-card") : null; }
  function containerOf(item) {
    if (!item) return null;
    if (item.classList.contains("product-card")) return item.closest("[data-product-grid]");
    return item.closest("[data-sortable]");
  }
  function isItem(ch) { return ch.hasAttribute("data-sid") || (ch.classList && ch.classList.contains("product-card")); }

  function markDraggable() {
    [].forEach.call(document.querySelectorAll("[data-sortable] > [data-sid]"), function (el) {
      el.setAttribute("draggable", "true");
    });
    [].forEach.call(document.querySelectorAll("[data-product-grid] > .product-card"), function (el) {
      el.setAttribute("draggable", "true");
    });
  }

  document.addEventListener("dragstart", function (e) {
    if (e.target.closest && e.target.closest(".staw-del")) return;
    var item = sortItem(e.target);
    if (!item) return;
    var c = containerOf(item);
    if (!c) return;
    dragged = item; dragContainer = c;
    item.classList.add("staw-dragging");
    if (e.dataTransfer) e.dataTransfer.effectAllowed = "move";
  });
  document.addEventListener("dragend", function () {
    if (!dragged) return;
    dragged.classList.remove("staw-dragging");
    saveOrder(dragContainer);
    dragged = null; dragContainer = null;
  });
  document.addEventListener("dragover", function (e) {
    if (!dragged || !dragContainer) return;
    e.preventDefault();
    var after = afterEl(dragContainer, e.clientX, e.clientY);
    if (after == null) dragContainer.appendChild(dragged);
    else if (after !== dragged) dragContainer.insertBefore(dragged, after);
  });

  function afterEl(c, x, y) {
    var els = [].filter.call(c.children, function (ch) {
      return isItem(ch) && !ch.classList.contains("staw-dragging");
    });
    for (var i = 0; i < els.length; i++) {
      var b = els[i].getBoundingClientRect();
      var cx = b.left + b.width / 2;
      // Первый элемент «после» курсора в порядке чтения (ряд ниже, либо тот же ряд правее центра).
      if (y < b.top || (y <= b.bottom && x < cx)) return els[i];
    }
    return null; // в конец
  }

  function saveOrder(c) {
    if (!c) return;
    var items = [].filter.call(c.children, isItem);
    if (c.hasAttribute("data-product-grid")) {
      send({ type: "reorder", platform: PLATFORM, order: items.map(function (ch) { return ch.getAttribute("data-id"); }) });
    } else {
      var g = c.getAttribute("data-sortable");
      if (g) draft("order." + g, JSON.stringify(items.map(function (ch) { return ch.getAttribute("data-sid"); })));
    }
  }

  // ── Клик: товар → правка товара; [data-edit-img] → фото; [data-edit] → текст ──
  document.addEventListener("click", function (e) {
    if (e.target.closest && e.target.closest(".staw-del")) return; // кнопка «Скрыть» — свой обработчик
    var card = e.target.closest(".product-card");
    if (card) { e.preventDefault(); e.stopPropagation(); send({ type: "editProduct", id: card.getAttribute("data-id") }); return; }
    var img = e.target.closest("[data-edit-img]");
    if (img) { e.preventDefault(); e.stopPropagation(); send({ type: "editImage", key: img.getAttribute("data-edit-img") }); return; }
    var ed = e.target.closest("[data-edit]");
    if (ed) {
      e.preventDefault(); e.stopPropagation();
      send({ type: "editContent", key: ed.getAttribute("data-edit"), value: ed.textContent.trim() });
    }
  }, true);

  // ── Кнопки «Скрыть ✕ / Вернуть» на удаляемых блоках ──
  var hideBtns = {};
  function updateHideBtn(key) {
    var rec = hideBtns[key];
    if (!rec) return;
    rec.btn.textContent = rec.el.classList.contains("staw-cms-hidden") ? "Вернуть" : "Скрыть ✕";
  }
  function initHide() {
    [].forEach.call(document.querySelectorAll("[data-hideable]"), function (el) {
      if (VOID_TAGS[el.tagName]) return;            // в <img> кнопку не вложить — только reorder/замена фото
      var key = el.getAttribute("data-hideable");
      if (!key || hideBtns[key]) return;
      var btn = document.createElement("button");
      btn.type = "button";
      btn.className = "staw-del";
      btn.draggable = false;
      el.appendChild(btn);
      hideBtns[key] = { btn: btn, el: el };
      updateHideBtn(key);
      btn.addEventListener("click", function (e) {
        e.preventDefault(); e.stopPropagation();
        var nowHidden = el.classList.toggle("staw-cms-hidden");
        updateHideBtn(key);
        draft("hidden." + key, nowHidden ? "1" : "");
      });
    });
  }

  // ── Применить черновик, присланный родителем (порядок/скрытие/текст) ──
  function reorderChildren(container, order) {
    if (!container || !Array.isArray(order)) return;
    var byId = {}, kids = [].slice.call(container.children);
    kids.forEach(function (ch) { var s = ch.getAttribute && ch.getAttribute("data-sid"); if (s) byId[s] = ch; });
    order.forEach(function (sid) { if (byId[sid]) { container.appendChild(byId[sid]); delete byId[sid]; } });
    kids.forEach(function (ch) { var s = ch.getAttribute && ch.getAttribute("data-sid"); if (s && byId[s]) container.appendChild(ch); });
  }
  function applyContent(key, value) {
    if (key.indexOf("order.") === 0) {
      var g = key.slice(6);
      if (!safeId(g) || !value) return;
      var order; try { order = JSON.parse(value); } catch (e) { return; }
      reorderChildren(document.querySelector('[data-sortable="' + g + '"]'), order);
      return;
    }
    if (key.indexOf("hidden.") === 0) {
      var hk = key.slice(7);
      if (!safeId(hk)) return;
      var hide = value === "1";
      document.querySelectorAll('[data-hideable="' + hk + '"]').forEach(function (el) {
        el.classList.toggle("staw-cms-hidden", hide);
      });
      updateHideBtn(hk);
      return;
    }
    if (!safeId(key)) return;
    var el = document.querySelector('[data-edit="' + key + '"]');
    if (el && typeof value === "string") el.textContent = value;
  }

  function cardById(id) {
    var cards = document.querySelectorAll(".product-card");
    for (var i = 0; i < cards.length; i++) if (cards[i].getAttribute("data-id") === id) return cards[i];
    return null;
  }
  function fmtPrice(v) { return new Intl.NumberFormat("ru-RU").format(Math.round(Number(v))) + " ₽"; }
  function applyCardFields(card, f) {
    if (f.price != null) { var pe = card.querySelector(".product-price"); if (pe) pe.textContent = fmtPrice(f.price); }
    if ("inStock" in f) {
      var se = card.querySelector(".product-stock");
      if (se) { se.textContent = f.inStock ? "В наличии" : "Скоро в продаже"; se.classList.toggle("product-stock--soon", !f.inStock); }
    }
  }

  // Сообщения от родителя (конструктора).
  window.addEventListener("message", function (e) {
    var d = e.data || {};
    if (d.source !== "staw-console") return;
    if (d.type === "reload") { location.reload(); return; }
    if (d.type === "setContent" && d.key) { applyContent(d.key, d.value); return; }
    if (d.type === "setOrder" && d.order && d.order.length) {
      var g = document.querySelector("[data-product-grid]");
      if (g) d.order.forEach(function (id) { var c = cardById(id); if (c) g.appendChild(c); });
      return;
    }
    if (d.type === "updateCard" && d.id && d.fields) { var card = cardById(d.id); if (card) applyCardFields(card, d.fields); return; }
    if (d.type === "setImage" && d.key && d.url) {
      document.querySelectorAll('[data-edit-img="' + d.key + '"]').forEach(function (el) {
        if (el.tagName === "IMG") el.src = d.url; else el.style.backgroundImage = "url('" + d.url + "')";
      });
    }
  });

  // Товары рендерятся асинхронно (catalog.js) — метим сразу и после ре-рендера.
  markDraggable();
  initHide();
  var grid = document.querySelector("[data-product-grid]");
  if (grid && window.MutationObserver) new MutationObserver(markDraggable).observe(grid, { childList: true });

  // ready шлём ПОСЛЕ того, как content.js применил базу (или по таймауту-страховке),
  // чтобы родитель наложил черновик поверх, а не был затёрт.
  var readySent = false;
  function fireReady() { if (readySent) return; readySent = true; send({ type: "ready", platform: PLATFORM }); }
  window.addEventListener("staw-content-applied", fireReady);
  setTimeout(fireReady, 1600);
})();
