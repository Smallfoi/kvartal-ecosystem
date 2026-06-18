/**
 * STAW сайт — подключение к общей экосистеме (единый аккаунт + баллы).
 *
 * Это самодостаточный модуль: он сам внедряет свой виджет в шапку, свои стили
 * и всю логику. Дизайн (вёрстку/CSS сайта) не трогает — «красоту» можно навести
 * потом, а виджет аккаунта легко перенести/перестилизовать (классы .eco-*).
 *
 * Бэкенд экосистемы (общий с Кварталом и SportStore):
 *   - POST /v1/auth/phone/verify {phone, code}  (dev-код: 1234) → {token, user}
 *   - GET  /v1/auth/me            (Bearer)       → профиль
 *   - GET  /v1/loyalty/account    (Bearer)       → {balance, level, transactions}
 *
 * ВАЖНО (dev): открывать сайт через локальный http-сервер (например
 *   `python -m http.server` в папке сайта), НЕ как file:// — иначе браузер
 *   заблокирует запросы к API. На том же ПК, где поднят backend на :8000.
 */
(function () {
  "use strict";

  // На том же ПК, где backend. Для прод заменить на https-домен API.
  var API = "http://127.0.0.1:8000/v1";
  var LS_TOKEN = "staw_jwt";
  var LS_USER = "staw_user";

  // ── storage ────────────────────────────────────────────────────────────────
  function getToken() {
    try { return localStorage.getItem(LS_TOKEN); } catch (e) { return null; }
  }
  function setSession(token, user) {
    try {
      localStorage.setItem(LS_TOKEN, token);
      localStorage.setItem(LS_USER, JSON.stringify(user || {}));
    } catch (e) {}
  }
  function getUser() {
    try { return JSON.parse(localStorage.getItem(LS_USER) || "null"); }
    catch (e) { return null; }
  }
  function clearSession() {
    try { localStorage.removeItem(LS_TOKEN); localStorage.removeItem(LS_USER); }
    catch (e) {}
  }

  // ── api ──────────────────────────────────────────────────────────────────
  function api(path, opts) {
    opts = opts || {};
    var headers = { "Content-Type": "application/json" };
    var t = getToken();
    if (t) headers["Authorization"] = "Bearer " + t;
    return fetch(API + path, {
      method: opts.method || "GET",
      headers: headers,
      body: opts.body ? JSON.stringify(opts.body) : undefined,
    }).then(function (r) {
      return r.text().then(function (txt) {
        var data = txt ? JSON.parse(txt) : null;
        if (!r.ok) {
          var msg = (data && data.detail) ? data.detail : "Ошибка сервера";
          throw new Error(msg);
        }
        return data;
      });
    });
  }

  // ── styles (инжектим, чтобы не трогать styles.css сайта) ────────────────────
  function injectStyles() {
    var css = ""
      + ".eco-account{display:flex;align-items:center;gap:10px;font-family:inherit}"
      + ".eco-btn{cursor:pointer;border:1px solid currentColor;background:transparent;"
      + "color:inherit;font:inherit;font-weight:600;padding:8px 14px;border-radius:999px;"
      + "letter-spacing:.02em}"
      + ".eco-points{display:inline-flex;align-items:center;gap:6px;font-weight:700;"
      + "padding:8px 12px;border-radius:999px;background:rgba(0,0,0,.06)}"
      + ".eco-user{font-weight:600;opacity:.85;max-width:140px;overflow:hidden;"
      + "text-overflow:ellipsis;white-space:nowrap}"
      + ".eco-link{cursor:pointer;background:none;border:none;color:inherit;font:inherit;"
      + "opacity:.6;text-decoration:underline}"
      + ".eco-modal{position:fixed;inset:0;z-index:9999;display:none;align-items:center;"
      + "justify-content:center;background:rgba(10,12,16,.55);backdrop-filter:blur(4px)}"
      + ".eco-modal.is-open{display:flex}"
      + ".eco-card{background:#fffdf8;color:#20252b;width:min(92vw,360px);border-radius:18px;"
      + "padding:24px;box-shadow:0 24px 60px rgba(0,0,0,.3)}"
      + ".eco-card h3{margin:0 0 4px;font-size:20px}"
      + ".eco-card p.eco-sub{margin:0 0 16px;opacity:.6;font-size:13px}"
      + ".eco-card input{width:100%;box-sizing:border-box;margin:6px 0;padding:12px 14px;"
      + "border:1px solid #d9d6cd;border-radius:12px;font:inherit;background:#fff}"
      + ".eco-card .eco-primary{width:100%;margin-top:10px;padding:13px;border:none;"
      + "border-radius:12px;background:#20252b;color:#fff;font:inherit;font-weight:700;cursor:pointer}"
      + ".eco-card .eco-primary[disabled]{opacity:.5;cursor:default}"
      + ".eco-err{color:#c0392b;font-size:13px;min-height:18px;margin:6px 0 0}"
      + ".eco-card .eco-close{float:right;background:none;border:none;font-size:20px;cursor:pointer;opacity:.5}";
    var s = document.createElement("style");
    s.setAttribute("data-eco-styles", "");
    s.textContent = css;
    document.head.appendChild(s);
  }

  // ── widget в шапке ──────────────────────────────────────────────────────────
  var widget;
  function mountWidget() {
    var header = document.querySelector(".site-header") || document.body;
    widget = document.createElement("div");
    widget.className = "eco-account";
    widget.setAttribute("data-eco-account", "");
    // вставляем перед кнопкой корзины, если она есть
    var cartBtn = header.querySelector(".cart-button");
    if (cartBtn) header.insertBefore(widget, cartBtn);
    else header.appendChild(widget);
  }

  function renderLoggedOut() {
    widget.innerHTML = '<button class="eco-btn" type="button" data-eco-login>Войти</button>';
    widget.querySelector("[data-eco-login]").addEventListener("click", openModal);
  }

  function renderLoggedIn(user, balance) {
    var name = (user && user.name) ? user.name : "Профиль";
    widget.innerHTML =
      '<span class="eco-points" title="Баллы экосистемы">★ ' + balance + "</span>" +
      '<span class="eco-user">' + escapeHtml(name) + "</span>" +
      '<button class="eco-link" type="button" data-eco-logout>Выйти</button>';
    widget.querySelector("[data-eco-logout]").addEventListener("click", function () {
      clearSession();
      renderLoggedOut();
    });
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  // ── login modal ──────────────────────────────────────────────────────────
  var modal;
  function buildModal() {
    modal = document.createElement("div");
    modal.className = "eco-modal";
    modal.innerHTML =
      '<div class="eco-card" role="dialog" aria-label="Вход в STAW">' +
      '<button class="eco-close" type="button" data-eco-x aria-label="Закрыть">×</button>' +
      "<h3>Вход в STAW</h3>" +
      '<p class="eco-sub">Единый аккаунт экосистемы: баллы из «Квартала» и магазина — общие. Dev-код: 1234.</p>' +
      '<input data-eco-phone type="tel" inputmode="tel" placeholder="Телефон, напр. +79148278470" autocomplete="tel" />' +
      '<input data-eco-code type="text" inputmode="numeric" placeholder="Код из SMS (dev: 1234)" autocomplete="one-time-code" />' +
      '<p class="eco-err" data-eco-err></p>' +
      '<button class="eco-primary" type="button" data-eco-submit>Войти</button>' +
      "</div>";
    document.body.appendChild(modal);
    modal.addEventListener("click", function (e) {
      if (e.target === modal) closeModal();
    });
    modal.querySelector("[data-eco-x]").addEventListener("click", closeModal);
    modal.querySelector("[data-eco-submit]").addEventListener("click", submitLogin);
  }
  function openModal() {
    if (!modal) buildModal();
    modal.querySelector("[data-eco-err]").textContent = "";
    modal.classList.add("is-open");
    modal.querySelector("[data-eco-phone]").focus();
  }
  function closeModal() { if (modal) modal.classList.remove("is-open"); }

  function submitLogin() {
    var phone = modal.querySelector("[data-eco-phone]").value.trim();
    var code = modal.querySelector("[data-eco-code]").value.trim();
    var errEl = modal.querySelector("[data-eco-err]");
    var btn = modal.querySelector("[data-eco-submit]");
    errEl.textContent = "";
    if (!phone) { errEl.textContent = "Введите телефон"; return; }
    if (!code) { errEl.textContent = "Введите код (dev: 1234)"; return; }
    btn.disabled = true;
    btn.textContent = "Входим…";
    api("/auth/phone/verify", { method: "POST", body: { phone: phone, code: code } })
      .then(function (data) {
        setSession(data.token, data.user);
        closeModal();
        refresh();
      })
      .catch(function (e) { errEl.textContent = e.message || "Не удалось войти"; })
      .then(function () { btn.disabled = false; btn.textContent = "Войти"; });
  }

  // ── refresh state ──────────────────────────────────────────────────────────
  function refresh() {
    if (!getToken()) { renderLoggedOut(); return; }
    // показываем кэш пока грузим
    renderLoggedIn(getUser(), "…");
    api("/loyalty/account")
      .then(function (acc) {
        var bal = (acc && typeof acc.balance === "number") ? acc.balance : 0;
        renderLoggedIn(getUser(), bal);
      })
      .catch(function (e) {
        // 401 → токен протух/неверен: разлогиниваем
        if (/токен/i.test(e.message) || /401/.test(e.message)) {
          clearSession();
          renderLoggedOut();
        } else {
          // сеть недоступна — оставляем имя, баллы «—»
          renderLoggedIn(getUser(), "—");
        }
      });
  }

  // ── init ─────────────────────────────────────────────────────────────────
  function init() {
    injectStyles();
    mountWidget();
    refresh();
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
