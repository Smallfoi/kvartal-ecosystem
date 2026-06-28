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

  // Базовый URL API экосистемы:
  //  - dev (сайт открыт на localhost/127.0.0.1) → локальный backend :8000;
  //  - прод → PROD_API ниже (заменить на реальный домен при деплое) либо
  //    переопределить, задав window.STAW_API_BASE ДО подключения ecosystem.js.
  var PROD_API = "https://api.staw.ru/v1"; // TODO: реальный домен API при деплое
  var host = location.hostname;
  var isDev = host === "localhost" || host === "127.0.0.1" || host === "";
  var API =
    (typeof window !== "undefined" && window.STAW_API_BASE) ||
    (isDev ? "http://127.0.0.1:8000/v1" : PROD_API);
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
      + ".eco-account-btn{display:inline-flex;align-items:center;gap:8px;cursor:pointer;"
      + "border:1px solid rgba(17,19,23,.14);background:transparent;color:inherit;font:inherit;"
      + "padding:5px 10px 5px 6px;border-radius:999px}"
      + ".eco-account-btn:hover{border-color:rgba(17,19,23,.32)}"
      + ".eco-btn{cursor:pointer;border:1px solid currentColor;background:transparent;"
      + "color:inherit;font:inherit;font-weight:600;padding:8px 14px;border-radius:999px;"
      + "letter-spacing:.02em}"
      + ".eco-points{display:inline-flex;align-items:center;gap:6px;font-weight:700;"
      + "padding:8px 12px;border-radius:999px;background:rgba(0,0,0,.06)}"
      + ".eco-user{font-weight:600;opacity:.85;max-width:140px;overflow:hidden;"
      + "text-overflow:ellipsis;white-space:nowrap}"
      + ".eco-avatar{width:26px;height:26px;border-radius:50%;object-fit:cover;flex:0 0 auto}"
      + ".eco-avatar--ini{display:inline-flex;align-items:center;justify-content:center;"
      + "background:rgba(0,0,0,.12);font-weight:700;font-size:12px;color:inherit}"
      + ".eco-link{cursor:pointer;background:none;border:none;color:inherit;font:inherit;"
      + "opacity:.6;text-decoration:underline}"
      + ".eco-modal{position:fixed;inset:0;z-index:9999;display:none;align-items:center;"
      + "justify-content:center;background:rgba(10,12,16,.55);backdrop-filter:blur(4px)}"
      + ".eco-modal.is-open{display:flex}"
      + ".eco-card{background:#fffdf8;color:#20252b;width:min(92vw,360px);border-radius:18px;"
      + "padding:24px;box-shadow:0 24px 60px rgba(0,0,0,.3)}"
      + ".eco-tabs{display:flex;gap:6px;margin:6px 0 14px;background:#f0ede5;padding:4px;border-radius:12px}"
      + ".eco-tab{flex:1;border:0;background:transparent;font:inherit;font-weight:700;color:#6f7278;"
      + "padding:9px;border-radius:9px;cursor:pointer}"
      + ".eco-tab.is-active{background:#fff;color:#20252b;box-shadow:0 1px 4px rgba(0,0,0,.08)}"
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
    // Контейнер действий шапки (.header-actions), иначе сама шапка/боди.
    var header =
      document.querySelector(".header-actions") ||
      document.querySelector(".site-header") ||
      document.body;
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
    widget.querySelector("[data-eco-login]").addEventListener("click", function () {
      openModal("login");
    });
    updateAuthUI(false);
  }

  function renderLoggedIn(user, balance) {
    // В шапке — только имя (полное имя видно в профиле).
    var full = (user && user.name) ? String(user.name).trim() : "";
    var name = full ? full.split(/\s+/)[0] : "Профиль";
    widget.innerHTML =
      '<button class="eco-account-btn" type="button" data-eco-profile aria-label="Открыть профиль">' +
      avatarHtml(user) +
      '<span class="eco-points" title="Баллы экосистемы">★ ' + balance + "</span>" +
      '<span class="eco-user">' + escapeHtml(name) + "</span>" +
      "</button>";
    widget.querySelector("[data-eco-profile]").addEventListener("click", function () {
      if (window.STAW && typeof window.STAW.openProfile === "function") {
        window.STAW.openProfile();
      }
    });
    updateAuthUI(true);
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  // Единый аватар экосистемы: /media/... → абсолютный URL (origin API без /v1).
  function avatarUrl(user) {
    var p = user && user.avatarPath;
    if (!p) return "";
    if (/^https?:/.test(p)) return p;
    return API.replace(/\/v1\/?$/, "") + (p.charAt(0) === "/" ? p : "/" + p);
  }
  // Аватар-кружок: фото с сервера, иначе инициал имени.
  function avatarHtml(user) {
    var av = avatarUrl(user);
    if (av) return '<img class="eco-avatar" src="' + av + '" alt="">';
    var full = (user && user.name) ? String(user.name).trim() : "";
    var ini = full ? full.charAt(0).toUpperCase() : "?";
    return '<span class="eco-avatar eco-avatar--ini">' + escapeHtml(ini) + "</span>";
  }

  // ── login / register modal ────────────────────────────────────────────────
  var modal;
  var ecoMode = "login"; // "login" | "register"

  function setMode(m) {
    ecoMode = m === "register" ? "register" : "login";
    var nameI = modal.querySelector("[data-eco-name]");
    var title = modal.querySelector("[data-eco-title]");
    var submit = modal.querySelector("[data-eco-submit]");
    modal.querySelectorAll("[data-eco-mode]").forEach(function (b) {
      b.classList.toggle("is-active", b.getAttribute("data-eco-mode") === ecoMode);
    });
    if (ecoMode === "register") {
      nameI.hidden = false;
      title.textContent = "Регистрация в STAW";
      submit.textContent = "Зарегистрироваться";
    } else {
      nameI.hidden = true;
      title.textContent = "Вход в STAW";
      submit.textContent = "Войти";
    }
    modal.querySelector("[data-eco-err]").textContent = "";
  }

  function buildModal() {
    modal = document.createElement("div");
    modal.className = "eco-modal";
    modal.innerHTML =
      '<div class="eco-card" role="dialog" aria-label="Вход и регистрация STAW">' +
      '<button class="eco-close" type="button" data-eco-x aria-label="Закрыть">×</button>' +
      '<div class="eco-tabs">' +
      '<button type="button" class="eco-tab is-active" data-eco-mode="login">Вход</button>' +
      '<button type="button" class="eco-tab" data-eco-mode="register">Регистрация</button>' +
      "</div>" +
      '<h3 data-eco-title>Вход в STAW</h3>' +
      '<p class="eco-sub">Единый аккаунт экосистемы: баллы из «Квартала», магазина и сайта — общие. Dev-код: 1234.</p>' +
      '<input data-eco-name type="text" placeholder="Имя и фамилия" autocomplete="name" hidden />' +
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
    modal.querySelector("[data-eco-submit]").addEventListener("click", submitAuth);
    modal.querySelectorAll("[data-eco-mode]").forEach(function (b) {
      b.addEventListener("click", function () { setMode(b.getAttribute("data-eco-mode")); });
    });
  }

  function openModal(mode) {
    if (!modal) buildModal();
    setMode(mode === "register" ? "register" : "login");
    modal.classList.add("is-open");
    modal.querySelector(ecoMode === "register" ? "[data-eco-name]" : "[data-eco-phone]").focus();
  }
  function closeModal() { if (modal) modal.classList.remove("is-open"); }

  function submitAuth() {
    var name = modal.querySelector("[data-eco-name]").value.trim();
    var phone = modal.querySelector("[data-eco-phone]").value.trim();
    var code = modal.querySelector("[data-eco-code]").value.trim();
    var errEl = modal.querySelector("[data-eco-err]");
    var btn = modal.querySelector("[data-eco-submit]");
    errEl.textContent = "";
    if (ecoMode === "register" && !name) { errEl.textContent = "Введите имя"; return; }
    if (!phone) { errEl.textContent = "Введите телефон"; return; }
    if (!code) { errEl.textContent = "Введите код (dev: 1234)"; return; }
    btn.disabled = true;
    btn.textContent = "…";
    // SSO по телефону: verify создаёт аккаунт при первом входе. В режиме
    // регистрации дополнительно сохраняем имя в профиль.
    api("/auth/phone/verify", { method: "POST", body: { phone: phone, code: code } })
      .then(function (data) {
        var user = data.user || {};
        if (ecoMode === "register" && name) user = Object.assign({}, user, { name: name });
        setSession(data.token, user);
        closeModal();
        refresh();
      })
      .catch(function (e) { errEl.textContent = e.message || "Не удалось"; })
      .then(function () { btn.disabled = false; setMode(ecoMode); });
  }

  // Показ/скрытие элементов по состоянию входа (CTA «Войти» прячем в аккаунте).
  function updateAuthUI(loggedIn) {
    document.querySelectorAll("[data-eco-login-cta]").forEach(function (el) {
      el.hidden = !!loggedIn;
    });
    document.querySelectorAll("[data-eco-auth-only]").forEach(function (el) {
      el.hidden = !loggedIn;
    });
  }

  // ── refresh state ──────────────────────────────────────────────────────────
  function refresh() {
    if (!getToken()) { renderLoggedOut(); return; }
    // показываем кэш пока грузим
    renderLoggedIn(getUser(), "…");
    // Полный профиль из бэкенда (имя/email/телефон/адреса) → обновляем сессию.
    api("/auth/me")
      .then(function (me) {
        if (me && me.id) {
          setSession(getToken(), me);
          renderLoggedIn(me, (window.STAW && window.STAW.ecoPoints) || "…");
        }
      })
      .catch(function () {});
    api("/loyalty/account")
      .then(function (acc) {
        var bal = (acc && typeof acc.balance === "number") ? acc.balance : 0;
        window.STAW = window.STAW || {};
        window.STAW.ecoPoints = bal;
        window.STAW.ecoLevel = (acc && acc.level) ? acc.level : null;
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
    // Внешние хуки экосистемы (вход/профиль/выход/данные).
    window.STAW = window.STAW || {};
    window.STAW.api = api; // авторизованный fetch к бэкенду (Bearer) для других модулей
    window.STAW.token = getToken;
    window.STAW.refreshAccount = refresh; // обновить баллы/профиль (напр. после заказа)
    window.STAW.openLogin = function () { openModal("login"); };
    window.STAW.openRegister = function () { openModal("register"); };
    window.STAW.getUser = getUser;
    window.STAW.logout = function () {
      clearSession();
      window.STAW.ecoPoints = 0;
      renderLoggedOut();
    };
    window.STAW.setUser = function (u) {
      try {
        localStorage.setItem(LS_USER, JSON.stringify(u || {}));
      } catch (e) {}
      if (getToken()) renderLoggedIn(u, (window.STAW && window.STAW.ecoPoints) || 0);
    };
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
