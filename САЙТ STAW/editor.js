/**
 * Режим редактирования сайта для «Конструктора» (мини-CMS, headless-подход).
 * Активируется ТОЛЬКО при ?edit=1 — на живом сайте не работает и не мешает.
 *
 * Что умеет (всё копится в ЧЕРНОВИК у родителя-конструктора, публикуется по кнопке):
 *  - клик по [data-edit]/[data-edit-img] → правка текста / фото;
 *  - клик по товару (.product-card) → правка товара;
 *  - перетаскивание в группе [data-sortable] → порядок (order.<group>); товары — reorder;
 *  - «➕ Добавить блок» в группе с <template> → новый блок (extra.<group>);
 *  - «Скрыть ✕/Вернуть» на [data-hideable] → hidden.<key>; на добавленном блоке — «Удалить ✕»;
 *  - «✨» на блоке → выбор анимации (anim.<key>);
 *  - контрол ⇤ ⇔ ⇥ у [data-align] → выравнивание группы (align.<key>).
 *
 * Кросс-домен: логика ЖИВЁТ В САЙТЕ, шлёт правки родителю через postMessage; сохраняет
 * их родитель. content.js применяет ПУБЛИКОВАННОЕ как базу и шлёт staw-content-applied —
 * только после этого мы шлём ready, чтобы родитель наложил черновик поверх (без гонки).
 */
(function () {
  "use strict";
  var params = new URLSearchParams(location.search);
  if (params.get("edit") !== "1") return;
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
    "html.staw-edit .staw-ui{font:600 11px/1 system-ui,-apple-system,sans-serif;cursor:pointer}" +
    "html.staw-edit .staw-del,html.staw-edit .staw-anim-btn{position:absolute;top:6px;z-index:30;border:0;border-radius:6px;" +
      "padding:3px 8px;color:#fff;box-shadow:0 1px 4px rgba(0,0,0,.3)}" +
    "html.staw-edit .staw-del{right:6px;background:rgba(17,24,39,.88)}" +
    "html.staw-edit .staw-anim-btn{right:64px;background:rgba(124,58,237,.9)}" +
    "html.staw-edit .staw-add{display:inline-flex;align-items:center;gap:6px;margin:12px auto;padding:9px 16px;" +
      "border:2px dashed #0a84ff;border-radius:10px;background:#eff6ff;color:#0a58ca;width:auto}" +
    "html.staw-edit .staw-align-bar{display:flex;gap:4px;justify-content:center;margin:0 0 8px}" +
    "html.staw-edit .staw-align-btn{border:1px solid #d1d5db;border-radius:6px;padding:3px 10px;background:#fff;color:#374151}" +
    "html.staw-edit .product-add,html.staw-edit [data-quick-view]{pointer-events:none}";
  document.documentElement.appendChild(css);
  document.documentElement.classList.add("staw-edit");

  function send(msg) { msg.source = "staw-editor"; if (window.parent !== window) window.parent.postMessage(msg, "*"); }
  function draft(key, value) { send({ type: "draftContent", key: key, value: value }); }
  function safeId(s) { return typeof s === "string" && /^[\w.-]+$/.test(s); }
  var VOID_TAGS = { IMG: 1, INPUT: 1, BR: 1, HR: 1, AREA: 1, EMBED: 1 };

  function isItem(ch) { return ch.hasAttribute("data-sid") || (ch.classList && ch.classList.contains("product-card")); }
  function sidsOf(container) { return [].filter.call(container.children, isItem).map(function (c) { return c.getAttribute("data-sid"); }); }
  function extrasOf(container) {
    return [].filter.call(container.children, function (c) { return c.hasAttribute("data-sid") && c.hasAttribute("data-extra"); })
      .map(function (c) { return c.getAttribute("data-sid"); });
  }

  // ── Перетаскивание (товары + любые [data-sortable]) ──
  var dragged = null, dragContainer = null;
  function sortItem(node) { return node && node.closest ? node.closest("[data-sid], .product-card") : null; }
  function containerOf(item) {
    if (!item) return null;
    if (item.classList.contains("product-card")) return item.closest("[data-product-grid]");
    return item.closest("[data-sortable]");
  }
  function markDraggable() {
    [].forEach.call(document.querySelectorAll("[data-sortable] > [data-sid]"), function (el) { el.setAttribute("draggable", "true"); });
    [].forEach.call(document.querySelectorAll("[data-product-grid] > .product-card"), function (el) { el.setAttribute("draggable", "true"); });
  }
  document.addEventListener("dragstart", function (e) {
    if (e.target.closest && e.target.closest(".staw-ui")) return;
    var item = sortItem(e.target); if (!item) return;
    var c = containerOf(item); if (!c) return;
    dragged = item; dragContainer = c; item.classList.add("staw-dragging");
    if (e.dataTransfer) e.dataTransfer.effectAllowed = "move";
  });
  document.addEventListener("dragend", function () {
    if (!dragged) return;
    dragged.classList.remove("staw-dragging");
    saveOrder(dragContainer); dragged = null; dragContainer = null;
  });
  document.addEventListener("dragover", function (e) {
    if (!dragged || !dragContainer) return;
    e.preventDefault();
    var after = afterEl(dragContainer, e.clientX, e.clientY);
    if (after == null) dragContainer.appendChild(dragged);
    else if (after !== dragged) dragContainer.insertBefore(dragged, after);
  });
  function afterEl(c, x, y) {
    var els = [].filter.call(c.children, function (ch) { return isItem(ch) && !ch.classList.contains("staw-dragging"); });
    for (var i = 0; i < els.length; i++) {
      var b = els[i].getBoundingClientRect(), cx = b.left + b.width / 2;
      if (y < b.top || (y <= b.bottom && x < cx)) return els[i];
    }
    return null;
  }
  function saveOrder(c) {
    if (!c) return;
    if (c.hasAttribute("data-product-grid")) {
      var ids = [].filter.call(c.children, isItem).map(function (ch) { return ch.getAttribute("data-id"); });
      send({ type: "reorder", platform: PLATFORM, order: ids });
    } else {
      var g = c.getAttribute("data-sortable");
      if (g) draft("order." + g, JSON.stringify(sidsOf(c)));
    }
  }

  // ── Клик: товар/фото/текст ──
  document.addEventListener("click", function (e) {
    if (e.target.closest && e.target.closest(".staw-ui")) return;
    var card = e.target.closest(".product-card");
    if (card) { e.preventDefault(); e.stopPropagation(); send({ type: "editProduct", id: card.getAttribute("data-id") }); return; }
    var img = e.target.closest("[data-edit-img]");
    if (img) { e.preventDefault(); e.stopPropagation(); send({ type: "editImage", key: img.getAttribute("data-edit-img") }); return; }
    var ed = e.target.closest("[data-edit]");
    if (ed) { e.preventDefault(); e.stopPropagation(); send({ type: "editContent", key: ed.getAttribute("data-edit"), value: ed.textContent.trim() }); }
  }, true);

  // ── Репитеры: клонирование из <template> ──
  function replaceTokens(node, sid) {
    var all = [node].concat([].slice.call(node.querySelectorAll ? node.querySelectorAll("*") : []));
    all.forEach(function (el) {
      ["data-sid", "data-hideable", "data-edit", "data-edit-img"].forEach(function (a) {
        var v = el.getAttribute && el.getAttribute(a);
        if (v && v.indexOf("{sid}") >= 0) el.setAttribute(a, v.replace(/\{sid\}/g, sid));
      });
    });
  }
  function makeSid() { return "n" + Date.now().toString(36) + Math.floor(Math.random() * 1e4).toString(36); }
  function templateFor(group) { return document.querySelector('template[data-block-template="' + group + '"]'); }
  function addBlock(group, container) {
    var tpl = templateFor(group);
    if (!tpl || !tpl.content || !tpl.content.firstElementChild) return;
    var sid = makeSid();
    var node = tpl.content.firstElementChild.cloneNode(true);
    replaceTokens(node, sid); node.setAttribute("data-extra", "1");
    container.appendChild(node);
    markDraggable(); initHideOn(node);
    draft("extra." + group, JSON.stringify(extrasOf(container)));
    draft("order." + group, JSON.stringify(sidsOf(container)));
  }
  function removeExtra(el) {
    var container = el.closest("[data-sortable]");
    var group = container && container.getAttribute("data-sortable");
    el.remove();
    if (group && container) {
      draft("extra." + group, JSON.stringify(extrasOf(container)));
      draft("order." + group, JSON.stringify(sidsOf(container)));
    }
  }
  function initAdders() {
    [].forEach.call(document.querySelectorAll("[data-sortable]"), function (container) {
      var group = container.getAttribute("data-sortable");
      if (!templateFor(group)) return;
      if (container.parentNode.querySelector('.staw-add[data-add="' + group + '"]')) return;
      var btn = document.createElement("button");
      btn.type = "button"; btn.className = "staw-ui staw-add"; btn.setAttribute("data-add", group);
      btn.textContent = "➕ Добавить блок";
      container.parentNode.insertBefore(btn, container.nextSibling);
      btn.addEventListener("click", function (e) { e.preventDefault(); e.stopPropagation(); addBlock(group, container); });
    });
  }

  // ── Выравнивание группы ──
  var ALIGN = { left: "flex-start", center: "center", right: "flex-end" };
  function applyAlignLocal(el, val) {
    if (!el) return;
    el.style.justifyContent = ALIGN[val] || "";
    el.style.textAlign = val === "right" ? "right" : val === "center" ? "center" : val === "left" ? "left" : "";
  }
  function initAlign() {
    [].forEach.call(document.querySelectorAll("[data-align]"), function (container) {
      var key = container.getAttribute("data-align");
      if (!key || container.parentNode.querySelector('.staw-align-bar[data-align-for="' + key + '"]')) return;
      var bar = document.createElement("div"); bar.className = "staw-ui staw-align-bar"; bar.setAttribute("data-align-for", key);
      [["left", "⇤"], ["center", "⇔"], ["right", "⇥"]].forEach(function (pair) {
        var b = document.createElement("button"); b.type = "button"; b.className = "staw-ui staw-align-btn"; b.textContent = pair[1];
        b.addEventListener("click", function (e) {
          e.preventDefault(); e.stopPropagation();
          applyAlignLocal(container, pair[0]); draft("align." + key, pair[0]);
        });
        bar.appendChild(b);
      });
      container.parentNode.insertBefore(bar, container);
    });
  }

  // ── Анимация блока ──
  function currentAnim(el) { var m = /\bstaw-anim-([\w-]+)/.exec(el.className); return m ? m[1] : ""; }
  function applyAnimLocal(key, val) {
    document.querySelectorAll('[data-hideable="' + key + '"]').forEach(function (el) {
      el.className = el.className.replace(/\s*\bstaw-anim-[\w-]+/g, "").trim();
      if (val && /^[\w-]+$/.test(val) && val !== "none") el.classList.add("staw-anim-" + val);
    });
  }

  // ── Кнопки блока: Скрыть/Вернуть (или Удалить для добавленного) + Анимация ──
  var hideBtns = {};
  function updateHideBtn(key) {
    var rec = hideBtns[key]; if (!rec) return;
    if (rec.el.hasAttribute("data-extra")) rec.btn.textContent = "Удалить ✕";
    else rec.btn.textContent = rec.el.classList.contains("staw-cms-hidden") ? "Вернуть" : "Скрыть ✕";
  }
  function initHideOn(el) {
    if (VOID_TAGS[el.tagName]) return; // в <img> кнопку не вложить
    var key = el.getAttribute("data-hideable");
    if (!key || hideBtns[key]) return;
    var del = document.createElement("button");
    del.type = "button"; del.className = "staw-ui staw-del"; del.draggable = false;
    el.appendChild(del);
    hideBtns[key] = { btn: del, el: el };
    updateHideBtn(key);
    del.addEventListener("click", function (e) {
      e.preventDefault(); e.stopPropagation();
      if (el.hasAttribute("data-extra")) { delete hideBtns[key]; removeExtra(el); return; }
      var nowHidden = el.classList.toggle("staw-cms-hidden");
      updateHideBtn(key); draft("hidden." + key, nowHidden ? "1" : "");
    });
    var anim = document.createElement("button");
    anim.type = "button"; anim.className = "staw-ui staw-anim-btn"; anim.draggable = false; anim.textContent = "✨";
    el.appendChild(anim);
    anim.addEventListener("click", function (e) {
      e.preventDefault(); e.stopPropagation();
      send({ type: "editAnim", key: key, value: currentAnim(el) });
    });
  }
  function initHide() { [].forEach.call(document.querySelectorAll("[data-hideable]"), initHideOn); }

  // ── Применить черновик от родителя ──
  function reorderChildren(container, order) {
    if (!container || !Array.isArray(order)) return;
    var byId = {}, kids = [].slice.call(container.children);
    kids.forEach(function (ch) { var s = ch.getAttribute && ch.getAttribute("data-sid"); if (s) byId[s] = ch; });
    order.forEach(function (sid) { if (byId[sid]) { container.appendChild(byId[sid]); delete byId[sid]; } });
    kids.forEach(function (ch) { var s = ch.getAttribute && ch.getAttribute("data-sid"); if (s && byId[s]) container.appendChild(ch); });
  }
  function materialize(group, val) {
    if (!safeId(group)) return;
    var extras; try { extras = JSON.parse(val); } catch (e) { return; }
    if (!Array.isArray(extras)) return;
    var tpl = templateFor(group), container = document.querySelector('[data-sortable="' + group + '"]');
    if (!tpl || !container || !tpl.content || !tpl.content.firstElementChild) return;
    extras.forEach(function (sid) {
      if (!safeId(sid) || container.querySelector('[data-sid="' + sid + '"]')) return;
      var node = tpl.content.firstElementChild.cloneNode(true);
      replaceTokens(node, sid); node.setAttribute("data-extra", "1");
      container.appendChild(node); markDraggable(); initHideOn(node);
    });
  }
  function applyContent(key, value) {
    if (key.indexOf("extra.") === 0) { materialize(key.slice(6), value); return; }
    if (key.indexOf("order.") === 0) {
      var g = key.slice(6); if (!safeId(g) || !value) return;
      var order; try { order = JSON.parse(value); } catch (e) { return; }
      reorderChildren(document.querySelector('[data-sortable="' + g + '"]'), order); return;
    }
    if (key.indexOf("hidden.") === 0) {
      var hk = key.slice(7); if (!safeId(hk)) return;
      var hide = value === "1";
      document.querySelectorAll('[data-hideable="' + hk + '"]').forEach(function (el) { el.classList.toggle("staw-cms-hidden", hide); });
      updateHideBtn(hk); return;
    }
    if (key.indexOf("align.") === 0) { var ak = key.slice(6); if (safeId(ak)) applyAlignLocal(document.querySelector('[data-align="' + ak + '"]'), value); return; }
    if (key.indexOf("anim.") === 0) { var nk = key.slice(5); if (safeId(nk)) applyAnimLocal(nk, value); return; }
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

  markDraggable(); initHide(); initAdders(); initAlign();
  var grid = document.querySelector("[data-product-grid]");
  if (grid && window.MutationObserver) new MutationObserver(markDraggable).observe(grid, { childList: true });

  var readySent = false;
  function fireReady() { if (readySent) return; readySent = true; send({ type: "ready", platform: PLATFORM }); }
  window.addEventListener("staw-content-applied", fireReady);
  setTimeout(fireReady, 1600);
})();
