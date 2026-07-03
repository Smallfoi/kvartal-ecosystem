/**
 * Режим редактирования сайта для «Конструктора» (мини-CMS, headless-подход).
 * Активируется ТОЛЬКО при ?edit=1 — на живом сайте не работает и не мешает.
 *
 * Идея (как в Storyblok/Contentful visual editor): конструктор в админке (:8000)
 * грузит РЕАЛЬНЫЙ сайт в iframe с ?edit=1 → это гарантирует идентичность (та же
 * 3-колоночная сетка, та же шапка). Правка происходит прямо на сайте:
 *  - перетаскивание карточек в настоящей сетке → новый порядок;
 *  - клик по карточке → правка товара;
 *  - клик по [data-edit] (тексты шапки/hero) → правка контента.
 * Кросс-домен: DOM iframe недоступен родителю, поэтому редактор ЖИВЁТ В САЙТЕ и
 * шлёт правки родителю через postMessage; сохраняет их авторизованно сам родитель
 * (у него сессия админки). Родитель отвечает — обновляем/перезагружаем.
 */
(function () {
  "use strict";
  var params = new URLSearchParams(location.search);
  if (params.get("edit") !== "1") return; // только в режиме редактирования
  var PLATFORM = params.get("platform") === "app" ? "app" : "site";

  var css = document.createElement("style");
  css.textContent =
    "html.staw-edit .product-card{cursor:grab;outline:2px dashed transparent;outline-offset:3px;transition:outline-color .12s}" +
    "html.staw-edit .product-card:hover{outline-color:#0a84ff}" +
    "html.staw-edit .product-card.staw-dragging{opacity:.4}" +
    "html.staw-edit [data-edit],html.staw-edit [data-edit-img]{outline:2px dashed transparent;outline-offset:3px;cursor:pointer;transition:outline-color .12s}" +
    "html.staw-edit [data-edit]:hover,html.staw-edit [data-edit-img]:hover{outline-color:#0a84ff}" +
    "html.staw-edit .product-add,html.staw-edit [data-quick-view],html.staw-edit .hero-actions a{pointer-events:none}";
  document.documentElement.appendChild(css);
  document.documentElement.classList.add("staw-edit");

  function send(msg) {
    msg.source = "staw-editor";
    if (window.parent !== window) window.parent.postMessage(msg, "*");
  }

  // ── Товары: перетаскивание в реальной сетке ──
  function grid() { return document.querySelector("[data-product-grid]"); }
  var dragged = null;

  document.addEventListener("dragstart", function (e) {
    var card = e.target.closest(".product-card");
    if (!card) return;
    dragged = card;
    card.classList.add("staw-dragging");
    e.dataTransfer.effectAllowed = "move";
  });
  document.addEventListener("dragend", function () {
    if (!dragged) return;
    dragged.classList.remove("staw-dragging");
    dragged = null;
    saveOrder();
  });
  document.addEventListener("dragover", function (e) {
    if (!dragged) return;
    var g = grid();
    if (!g) return;
    e.preventDefault();
    var after = afterEl(g, e.clientX, e.clientY);
    if (after == null) g.appendChild(dragged);
    else g.insertBefore(dragged, after);
  });

  function afterEl(g, x, y) {
    var els = [].slice.call(g.querySelectorAll(".product-card:not(.staw-dragging)"));
    for (var i = 0; i < els.length; i++) {
      var b = els[i].getBoundingClientRect();
      var cx = b.left + b.width / 2;
      // Первая карточка, которая "после" курсора в порядке чтения (ряд ниже, либо тот же ряд правее центра).
      if (y < b.top || (y <= b.bottom && x < cx)) return els[i];
    }
    return null; // в конец
  }

  function saveOrder() {
    var g = grid();
    if (!g) return;
    var order = [].slice.call(g.querySelectorAll(".product-card")).map(function (c) {
      return c.getAttribute("data-id");
    });
    send({ type: "reorder", platform: PLATFORM, order: order });
  }

  function markDraggable() {
    [].slice.call(document.querySelectorAll(".product-card")).forEach(function (c) {
      c.setAttribute("draggable", "true");
    });
  }

  // ── Клик: товар → правка товара; [data-edit]/[data-edit-img] → правка контента ──
  document.addEventListener(
    "click",
    function (e) {
      var card = e.target.closest(".product-card");
      if (card) {
        e.preventDefault();
        e.stopPropagation();
        send({ type: "editProduct", id: card.getAttribute("data-id") });
        return;
      }
      var img = e.target.closest("[data-edit-img]");
      if (img) {
        e.preventDefault();
        e.stopPropagation();
        send({ type: "editImage", key: img.getAttribute("data-edit-img") });
        return;
      }
      var ed = e.target.closest("[data-edit]");
      if (ed) {
        e.preventDefault();
        e.stopPropagation();
        send({
          type: "editContent",
          key: ed.getAttribute("data-edit"),
          value: ed.textContent.trim(),
        });
      }
    },
    true,
  );

  // Товары рендерятся асинхронно (catalog.js) — метим сразу и после ре-рендера.
  markDraggable();
  var g = grid();
  if (g && window.MutationObserver) {
    new MutationObserver(markDraggable).observe(g, { childList: true });
  }

  // Найти карточку по data-id (без селектор-инъекций).
  function cardById(id) {
    var cards = document.querySelectorAll(".product-card");
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].getAttribute("data-id") === id) return cards[i];
    }
    return null;
  }
  function fmtPrice(v) {
    return new Intl.NumberFormat("ru-RU").format(Math.round(Number(v))) + " ₽";
  }
  // Применить черновые поля товара к карточке (превью до публикации).
  function applyCardFields(card, f) {
    if (f.price != null) {
      var pe = card.querySelector(".product-price");
      if (pe) pe.textContent = fmtPrice(f.price);
    }
    if ("inStock" in f) {
      var se = card.querySelector(".product-stock");
      if (se) {
        se.textContent = f.inStock ? "В наличии" : "Скоро в продаже";
        se.classList.toggle("product-stock--soon", !f.inStock);
      }
    }
  }

  // Сообщения от родителя (конструктора).
  window.addEventListener("message", function (e) {
    var d = e.data || {};
    if (d.source !== "staw-console") return;
    if (d.type === "reload") { location.reload(); return; }
    if (d.type === "setContent" && d.key) {
      var el = document.querySelector('[data-edit="' + d.key + '"]');
      if (el && typeof d.value === "string") el.textContent = d.value;
    }
    if (d.type === "setOrder" && d.order && d.order.length) {
      var g = grid();
      if (g) {
        d.order.forEach(function (id) {
          var c = cardById(id);
          if (c) g.appendChild(c);
        });
      }
    }
    if (d.type === "updateCard" && d.id && d.fields) {
      var card = cardById(d.id);
      if (card) applyCardFields(card, d.fields);
    }
    // Черновое фото (превью до публикации): подставляем data-URL/URL.
    if (d.type === "setImage" && d.key && d.url) {
      document.querySelectorAll('[data-edit-img="' + d.key + '"]').forEach(function (el) {
        if (el.tagName === "IMG") el.src = d.url;
        else el.style.backgroundImage = "url('" + d.url + "')";
      });
    }
  });

  send({ type: "ready", platform: PLATFORM });
})();
