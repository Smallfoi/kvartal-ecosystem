/**
 * Мини-CMS: сайт читает редактируемый контент из общего бэкенда (/site/content)
 * и подставляет его в элементы. Всё это задаёт владелец в «Конструкторе».
 * Ключи:
 *   - data-edit / data-edit-img → текст / фото;
 *   - order.<group>   → порядок карточек в [data-sortable="<group>"];
 *   - hidden.<key>    → скрытые блоки [data-hideable="<key>"] ("1");
 *   - extra.<group>   → ДОБАВЛЕННЫЕ блоки (репитеры): JSON-массив новых sid,
 *                       каждый клонируется из <template data-block-template="<group>">;
 *   - align.<key>     → выравнивание группы [data-align="<key>"] (left/center/right);
 *   - anim.<key>      → анимация блока [data-hideable="<key>"] (fade-up/…).
 * Нет контента — остаётся HTML по умолчанию. Офлайн/нет API — сайт не ломается.
 *
 * В режиме правки (?edit=1) скрытые блоки не убираются, а приглушаются (editor.js
 * покажет кнопку «Вернуть»). Порядок/тексты/фото/блоки применяются как база, поверх
 * которой editor.js кладёт черновик; чтобы не затереть — по событию staw-content-applied.
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

  function mediaUrl(u) { return !u ? "" : (u.indexOf("http") === 0 ? u : ORIGIN + u); }
  function safeId(s) { return typeof s === "string" && /^[\w.-]+$/.test(s); }
  function parseArr(v) { try { var a = JSON.parse(v); return Array.isArray(a) ? a : null; } catch (e) { return null; } }

  // ── Анимации: CSS-пресеты (инъекция один раз; на живом сайте эффекта нет, пока не задан anim.<key>) ──
  function injectAnimCss() {
    if (document.getElementById("staw-anim-css")) return;
    var st = document.createElement("style");
    st.id = "staw-anim-css";
    st.textContent =
      "@keyframes staw-fu{from{opacity:0;transform:translateY(24px)}to{opacity:1;transform:none}}" +
      ".staw-anim-fade-up{animation:staw-fu .7s ease both}" +
      "@keyframes staw-fi{from{opacity:0}to{opacity:1}}" +
      ".staw-anim-fade-in{animation:staw-fi .9s ease both}" +
      "@keyframes staw-sl{from{opacity:0;transform:translateX(-40px)}to{opacity:1;transform:none}}" +
      ".staw-anim-slide-left{animation:staw-sl .7s ease both}" +
      "@keyframes staw-sr{from{opacity:0;transform:translateX(40px)}to{opacity:1;transform:none}}" +
      ".staw-anim-slide-right{animation:staw-sr .7s ease both}" +
      "@keyframes staw-zm{from{opacity:0;transform:scale(.9)}to{opacity:1;transform:none}}" +
      ".staw-anim-zoom{animation:staw-zm .7s ease both}" +
      "@keyframes staw-pl{0%,100%{transform:scale(1)}50%{transform:scale(1.04)}}" +
      ".staw-anim-pulse{animation:staw-pl 1.8s ease-in-out infinite}";
    (document.head || document.documentElement).appendChild(st);
  }

  // ── Репитеры: клонировать добавленные блоки из <template> ──
  function replaceTokens(node, sid) {
    var all = [node].concat([].slice.call(node.querySelectorAll ? node.querySelectorAll("*") : []));
    all.forEach(function (el) {
      ["data-sid", "data-hideable", "data-edit", "data-edit-img"].forEach(function (a) {
        var v = el.getAttribute && el.getAttribute(a);
        if (v && v.indexOf("{sid}") >= 0) el.setAttribute(a, v.replace(/\{sid\}/g, sid));
      });
    });
  }
  function materialize(group, val) {
    if (!safeId(group)) return;
    var extras = parseArr(val);
    if (!extras) return;
    var tpl = document.querySelector('template[data-block-template="' + group + '"]');
    var container = document.querySelector('[data-sortable="' + group + '"]');
    if (!tpl || !container || !tpl.content || !tpl.content.firstElementChild) return;
    extras.forEach(function (sid) {
      if (!safeId(sid)) return;
      if (container.querySelector('[data-sid="' + sid + '"]')) return; // уже есть
      var node = tpl.content.firstElementChild.cloneNode(true);
      replaceTokens(node, sid);
      node.setAttribute("data-extra", "1");
      container.appendChild(node);
    });
  }

  function reorderChildren(container, order) {
    if (!container || !Array.isArray(order)) return;
    var byId = {}, kids = [].slice.call(container.children);
    kids.forEach(function (ch) { var s = ch.getAttribute && ch.getAttribute("data-sid"); if (s) byId[s] = ch; });
    order.forEach(function (sid) { if (byId[sid]) { container.appendChild(byId[sid]); delete byId[sid]; } });
    kids.forEach(function (ch) { var s = ch.getAttribute && ch.getAttribute("data-sid"); if (s && byId[s]) container.appendChild(ch); });
  }
  function applyOrder(group, val) {
    if (!safeId(group)) return;
    var order = parseArr(val);
    if (order) reorderChildren(document.querySelector('[data-sortable="' + group + '"]'), order);
  }
  function applyHidden(key, val) {
    if (!safeId(key)) return;
    var hide = val === "1";
    document.querySelectorAll('[data-hideable="' + key + '"]').forEach(function (el) {
      if (EDIT) { el.classList.toggle("staw-cms-hidden", hide); el.style.display = ""; }
      else { el.style.display = hide ? "none" : ""; }
    });
  }
  var ALIGN = { left: "flex-start", center: "center", right: "flex-end", start: "flex-start", end: "flex-end" };
  function applyAlign(key, val) {
    if (!safeId(key)) return;
    var el = document.querySelector('[data-align="' + key + '"]');
    if (!el) return;
    var j = ALIGN[val];
    el.style.justifyContent = j || "";
    el.style.textAlign = val === "right" ? "right" : val === "center" ? "center" : val === "left" ? "left" : "";
  }
  function applyAnim(key, val) {
    if (!safeId(key)) return;
    document.querySelectorAll('[data-hideable="' + key + '"]').forEach(function (el) {
      el.className = el.className.replace(/\s*\bstaw-anim-[\w-]+/g, "").trim();
      if (val && /^[\w-]+$/.test(val) && val !== "none") el.classList.add("staw-anim-" + val);
    });
  }

  function apply(content) {
    if (!content) return;
    injectAnimCss();
    // 1) сначала материализуем добавленные блоки — чтобы их ключи было куда применять
    Object.keys(content).forEach(function (k) {
      if (k.indexOf("extra.") === 0) { try { materialize(k.slice(6), (content[k] || {}).value); } catch (e) {} }
    });
    // 2) основной проход
    Object.keys(content).forEach(function (key) {
      try {
        var c = content[key] || {};
        if (key.indexOf("order.") === 0) { applyOrder(key.slice(6), c.value); return; }
        if (key.indexOf("hidden.") === 0) { applyHidden(key.slice(7), c.value); return; }
        if (key.indexOf("align.") === 0) { applyAlign(key.slice(6), c.value); return; }
        if (key.indexOf("anim.") === 0) { applyAnim(key.slice(5), c.value); return; }
        if (key.indexOf("extra.") === 0) { return; } // уже применили выше
        if (c.value && safeId(key)) {
          document.querySelectorAll('[data-edit="' + key + '"]').forEach(function (el) { el.textContent = c.value; });
        }
        if (c.imageUrl && safeId(key)) {
          var url = mediaUrl(c.imageUrl);
          document.querySelectorAll('[data-edit-img="' + key + '"]').forEach(function (el) {
            if (el.tagName === "IMG") el.src = url; else el.style.backgroundImage = "url('" + url + "')";
          });
        }
      } catch (e) { /* один плохой ключ не ломает остальные */ }
    });
  }

  function done() { try { if (EDIT) window.dispatchEvent(new Event("staw-content-applied")); } catch (e) {} }

  injectAnimCss(); // на случай пустого ответа — пресеты уже есть
  fetch(API + "/site/content")
    .then(function (r) { return r.ok ? r.json() : Promise.reject(); })
    .then(apply)
    .then(done)
    .catch(function () { done(); });
})();
