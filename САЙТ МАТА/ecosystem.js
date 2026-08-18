/**
 * МАТА сайт — подключение к общей экосистеме (единый аккаунт + баллы).
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
  var PROD_API = "https://api.mata-store.ru/v1"; // TODO: реальный домен API при деплое
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
      // Аватар в панели профиля — кликабелен (смена фото), фото фоном.
      + ".pr-avatar{cursor:pointer;background-size:cover;background-position:center;position:relative}"
      + ".pr-avatar::after{content:'📷';position:absolute;right:-2px;bottom:-2px;font-size:11px;"
      + "background:#20252b;border-radius:50%;width:18px;height:18px;display:flex;align-items:center;"
      + "justify-content:center;box-shadow:0 0 0 2px #fffdf8}"
      + ".pr-avatar.has-photo{color:transparent;text-shadow:none}"
      + ".pr-avatar-remove{display:block;background:none;border:none;color:#c0392b;font:inherit;"
      + "font-size:12px;cursor:pointer;padding:4px 0 0;text-decoration:underline}"
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
      + ".eco-card .eco-close{float:right;background:none;border:none;font-size:20px;cursor:pointer;opacity:.5}"
      // ── Ввод кода: хореография «OTP V5» (стандарт анимаций экосистемы) ──
      + ".eco-otp{position:relative;height:196px;margin:10px 0 0;cursor:text}"
      + ".eco-card input.eco-otp-input{position:absolute;left:50%;top:50%;width:1px;height:1px;"
      + "opacity:0;border:0;padding:0;margin:0;background:transparent}"
      + ".eco-otp-cell{position:absolute;left:50%;top:50%;width:52px;height:62px;"
      + "margin:-31px 0 0 -26px;border-radius:14px;background:#fff;border:1px solid #d9d6cd;"
      + "display:flex;align-items:center;justify-content:center;font-size:24px;font-weight:700;"
      + "color:#20252b;will-change:transform;transition:border-color .25s,box-shadow .25s,background .3s}"
      + ".eco-otp-cell.has{border-color:#20252b;border-width:2px}"
      + ".eco-otp-cell.active{border-color:#20252b;border-width:2px;box-shadow:0 0 14px rgba(32,37,43,.18)}"
      + ".eco-otp-cell.err{border-color:#c0392b;color:#c0392b}"
      + ".eco-otp-cell.ok{border-color:#16a34a;background:#eefaf1;box-shadow:0 0 22px rgba(22,163,74,.35)}"
      + ".eco-otp-caret{width:2px;height:24px;background:#20252b;animation:ecoBlink 1s steps(1) infinite}"
      + "@keyframes ecoBlink{50%{opacity:0}}"
      + ".eco-otp-ring{position:absolute;left:50%;top:50%;width:70px;height:70px;margin:-35px 0 0 -35px;"
      + "border-radius:50%;border:1.5px solid #16a34a;pointer-events:none;"
      + "animation:ecoRipple 1.2s cubic-bezier(.22,1,.36,1) forwards}"
      + ".eco-otp-ring.d2{animation-delay:.22s;opacity:0}"
      + "@keyframes ecoRipple{0%{transform:scale(.55);opacity:.9}100%{transform:scale(3.2);opacity:0}}"
      + ".eco-otp-spark{position:absolute;left:50%;top:50%;width:4px;height:4px;border-radius:50%;"
      + "background:#4ade80;opacity:0;animation:ecoFly .9s ease-out forwards;animation-delay:var(--d)}"
      + "@keyframes ecoFly{0%{opacity:0;transform:rotate(var(--a)) translateX(18px) scale(.4)}"
      + "35%{opacity:1}100%{opacity:0;transform:rotate(var(--a)) translateX(84px) scale(.2)}}"
      + ".eco-otp-check{stroke-dasharray:30;stroke-dashoffset:30;"
      + "animation:ecoDraw .45s .1s cubic-bezier(.65,0,.35,1) forwards}"
      + "@keyframes ecoDraw{to{stroke-dashoffset:0}}"
      + ".eco-otp.shake{animation:ecoShake .32s ease}"
      + "@keyframes ecoShake{10%,90%{transform:translateX(-2px)}20%,80%{transform:translateX(3px)}"
      + "30%,50%,70%{transform:translateX(-4px)}40%,60%{transform:translateX(4px)}}"
      + "@media(prefers-reduced-motion:reduce){.eco-otp-ring,.eco-otp-spark{animation:none;opacity:0}"
      + ".eco-otp.shake{animation:none}.eco-otp-check{animation:none;stroke-dashoffset:0}}";
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
      title.textContent = "Регистрация в МАТА";
      submit.textContent = "Зарегистрироваться";
    } else {
      nameI.hidden = true;
      title.textContent = "Вход в МАТА";
      submit.textContent = "Войти";
    }
    modal.querySelector("[data-eco-err]").textContent = "";
  }

  function buildModal() {
    modal = document.createElement("div");
    modal.className = "eco-modal";
    modal.innerHTML =
      '<div class="eco-card" role="dialog" aria-label="Вход и регистрация МАТА">' +
      '<button class="eco-close" type="button" data-eco-x aria-label="Закрыть">×</button>' +
      '<div class="eco-tabs">' +
      '<button type="button" class="eco-tab is-active" data-eco-mode="login">Вход</button>' +
      '<button type="button" class="eco-tab" data-eco-mode="register">Регистрация</button>' +
      "</div>" +
      '<h3 data-eco-title>Вход в МАТА</h3>' +
      '<p class="eco-sub">Единый аккаунт экосистемы: баллы из «Квартала», магазина и сайта — общие. Dev-код: 1234.</p>' +
      '<input data-eco-name type="text" placeholder="Имя и фамилия" autocomplete="name" hidden />' +
      '<input data-eco-phone type="tel" inputmode="tel" placeholder="Телефон, напр. +79148278470" autocomplete="tel" />' +
      '<div class="eco-otp" data-eco-otp>' +
      '<input data-eco-code class="eco-otp-input" type="text" inputmode="numeric" maxlength="4" autocomplete="one-time-code" aria-label="Код из SMS" />' +
      "</div>" +
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
    setupOtp();
  }

  function openModal(mode) {
    if (!modal) buildModal();
    setMode(mode === "register" ? "register" : "login");
    modal.classList.add("is-open");
    modal.querySelector(ecoMode === "register" ? "[data-eco-name]" : "[data-eco-phone]").focus();
  }
  function closeModal() {
    if (!modal) return;
    modal.classList.remove("is-open");
    // Закрыли на середине хореографии — остановить и вернуть строку.
    if (otpBusy || otpRaf) otpReset();
  }

  // ── Ввод кода: «OTP V5» — строка → круг → жёсткое вращение → схлопывание ──
  // Стандарт анимаций верификации экосистемы МАТА (директива владельца).
  // Движение пишется прямо в style.transform из rAF — без перерисовок DOM.
  var OTP_LEN = 4, OTP_GAP = 66, OTP_R = 56, OTP_TURNS = 2;
  var otpCells = [], otpInput = null, otpStage = null;
  var otpPhase = "input"; // input|explode|spin|spinwait|collapse|reverse
  var otpT0 = 0, otpExtra = 0, otpRaf = 0, otpBusy = false;
  var otpResult = null; // null=ждём, {ok:true,data}|{ok:false,msg}

  function otpReduced() {
    return window.matchMedia &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }
  function easeOutCubic(t) { return 1 - Math.pow(1 - t, 3); }
  function easeInOutCubic(t) {
    return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
  }
  function easeInBack(t) { return 2.2 * t * t * t - 1.2 * t * t; }

  function setupOtp() {
    otpStage = modal.querySelector("[data-eco-otp]");
    otpInput = modal.querySelector("[data-eco-code]");
    otpCells = [];
    for (var i = 0; i < OTP_LEN; i++) {
      var c = document.createElement("div");
      c.className = "eco-otp-cell";
      otpStage.appendChild(c);
      otpCells.push(c);
    }
    otpStage.addEventListener("click", function () {
      if (!otpBusy) otpInput.focus();
    });
    otpInput.addEventListener("input", function () {
      otpInput.value = otpInput.value.replace(/\D/g, "").slice(0, OTP_LEN);
      renderOtp();
      if (otpInput.value.length === OTP_LEN && !otpBusy) submitAuth();
    });
    otpInput.addEventListener("focus", function () { renderOtp(); });
    otpInput.addEventListener("blur", function () { renderOtp(); });
    otpLayoutRow();
    renderOtp();
  }

  // Статичная строка (когда rAF не крутится).
  function otpLayoutRow() {
    for (var i = 0; i < OTP_LEN; i++) {
      var x = (i - (OTP_LEN - 1) / 2) * OTP_GAP;
      otpCells[i].style.transform = "translate(" + x + "px,0)";
      otpCells[i].style.opacity = 1;
    }
  }

  // Цифры/каретка/классы ячеек.
  function renderOtp(errFlag) {
    var v = otpInput ? otpInput.value : "";
    var focused = otpInput && document.activeElement === otpInput;
    for (var i = 0; i < OTP_LEN; i++) {
      var cell = otpCells[i];
      var ch = i < v.length ? v.charAt(i) : "";
      var isCur = !otpBusy && focused && i === v.length;
      cell.textContent = ch;
      if (isCur && !ch) {
        var caret = document.createElement("span");
        caret.className = "eco-otp-caret";
        cell.appendChild(caret);
      }
      cell.classList.toggle("has", !!ch);
      cell.classList.toggle("active", isCur);
      cell.classList.toggle("err", !!errFlag);
      cell.classList.remove("ok");
    }
  }

  // Один кадр хореографии: позиции всех ячеек из текущей фазы.
  function otpFrame(now) {
    var el = now - otpT0;
    var p = 1, spin = 0, shrink = 0;

    if (otpPhase === "explode") {
      p = easeOutCubic(Math.min(el / 380, 1));
      if (el >= 380) { otpPhase = "spin"; otpT0 = now; }
    } else if (otpPhase === "spin") {
      spin = easeInOutCubic(Math.min(el / 1250, 1)) * 360 * OTP_TURNS;
      if (el >= 1250) {
        otpT0 = now;
        otpPhase = otpResult === null
          ? "spinwait"
          : otpResult.ok ? "collapse" : "reverse";
      }
    } else if (otpPhase === "spinwait") {
      // Сервер ещё думает: докручиваем по обороту (вращение = «загрузка»).
      spin = 360 * OTP_TURNS + otpExtra +
        easeInOutCubic(Math.min(el / 800, 1)) * 360;
      if (el >= 800) {
        otpExtra += 360;
        otpT0 = now;
        if (otpResult !== null) {
          otpPhase = otpResult.ok ? "collapse" : "reverse";
        }
      }
    } else if (otpPhase === "collapse") {
      var t = Math.min(el / 420, 1);
      spin = 360 * OTP_TURNS + otpExtra + easeOutCubic(t) * 40;
      shrink = easeInBack(t);
      if (el >= 420) { otpFinishSuccess(); return; }
    } else if (otpPhase === "reverse") {
      // Ошибка: быстрая обратная раскрутка в строку.
      var r = 1 - easeInOutCubic(Math.min(el / 420, 1));
      p = r;
      spin = (360 * OTP_TURNS + otpExtra) * r;
      if (el >= 420) { otpFinishError(); return; }
    }

    for (var i = 0; i < OTP_LEN; i++) {
      var rowX = (i - (OTP_LEN - 1) / 2) * OTP_GAP;
      var a = ((-90 + i * (360 / OTP_LEN) + spin) * Math.PI) / 180;
      var x = (rowX + (Math.cos(a) * OTP_R - rowX) * p) * (1 - shrink);
      var y = Math.sin(a) * OTP_R * p * (1 - shrink);
      var rot = spin * p;
      var sc = 1 - shrink * 0.12;
      var op = shrink > 0.75 && i !== 0 ? 1 - (shrink - 0.75) / 0.25 : 1;
      otpCells[i].style.transform =
        "translate(" + x.toFixed(2) + "px," + y.toFixed(2) + "px)" +
        " rotate(" + rot.toFixed(2) + "deg) scale(" + sc.toFixed(3) + ")";
      otpCells[i].style.opacity = op;
    }
    otpRaf = requestAnimationFrame(otpFrame);
  }

  function otpFinishSuccess() {
    otpRaf = 0;
    // Схлопнуто: остаётся первая ячейка — зелёная, с прорисовкой галочки.
    for (var i = 1; i < OTP_LEN; i++) otpCells[i].style.opacity = 0;
    var c0 = otpCells[0];
    c0.style.transform = "translate(0,0) scale(.92)";
    c0.classList.remove("err", "active", "has");
    c0.classList.add("ok");
    c0.innerHTML =
      '<svg viewBox="0 0 24 24" width="26" height="26">' +
      '<path class="eco-otp-check" d="M5 12.5l4.5 4.5L19 7.5" fill="none" ' +
      'stroke="#16a34a" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>';
    for (var r = 0; r < 2; r++) {
      var ring = document.createElement("div");
      ring.className = "eco-otp-ring" + (r ? " d2" : "");
      otpStage.appendChild(ring);
    }
    for (var s = 0; s < 6; s++) {
      var sp = document.createElement("span");
      sp.className = "eco-otp-spark";
      sp.style.setProperty("--a", (s * 60 + 20) + "deg");
      sp.style.setProperty("--d", (s * 60) + "ms");
      otpStage.appendChild(sp);
    }
    var title = modal.querySelector("[data-eco-title]");
    if (title) title.textContent = "Готово! Вы вошли";
    setTimeout(function () {
      if (!otpResult) return; // сброшено (модалку закрыли раньше)
      var data = otpResult.data;
      var name = modal.querySelector("[data-eco-name]").value.trim();
      var user = (data && data.user) || {};
      if (ecoMode === "register" && name) user = Object.assign({}, user, { name: name });
      if (data) setSession(data.token, user);
      closeModal();
      refresh();
      otpReset();
    }, 1200);
  }

  function otpFinishError() {
    otpRaf = 0;
    otpBusy = false;
    otpLayoutRow();
    otpInput.value = "";
    renderOtp(true);
    otpStage.classList.add("shake");
    setTimeout(function () { otpStage.classList.remove("shake"); }, 360);
    var errEl = modal.querySelector("[data-eco-err]");
    errEl.textContent = (otpResult && otpResult.msg) || "Не удалось войти";
    var btn = modal.querySelector("[data-eco-submit]");
    btn.disabled = false;
    otpResult = null;
    otpExtra = 0;
    otpInput.focus();
  }

  function otpReset() {
    if (otpRaf) { cancelAnimationFrame(otpRaf); otpRaf = 0; }
    otpBusy = false;
    otpResult = null;
    otpExtra = 0;
    otpPhase = "input";
    otpInput.value = "";
    // убрать кольца/искры финала
    var fx = otpStage.querySelectorAll(".eco-otp-ring,.eco-otp-spark");
    for (var i = 0; i < fx.length; i++) fx[i].parentNode.removeChild(fx[i]);
    otpLayoutRow();
    renderOtp();
    var btn = modal.querySelector("[data-eco-submit]");
    if (btn) btn.disabled = false;
  }

  function submitAuth() {
    if (otpBusy) return;
    var name = modal.querySelector("[data-eco-name]").value.trim();
    var phone = modal.querySelector("[data-eco-phone]").value.trim();
    var code = otpInput.value.trim();
    var errEl = modal.querySelector("[data-eco-err]");
    var btn = modal.querySelector("[data-eco-submit]");
    errEl.textContent = "";
    if (ecoMode === "register" && !name) { errEl.textContent = "Введите имя"; return; }
    if (!phone) { errEl.textContent = "Введите телефон"; return; }
    if (code.length < OTP_LEN) { errEl.textContent = "Введите код (dev: 1234)"; return; }

    otpBusy = true;
    otpResult = null;
    otpExtra = 0;
    btn.disabled = true;
    otpInput.blur();
    renderOtp();

    // SSO по телефону: verify создаёт аккаунт при первом входе; запрос идёт
    // ПАРАЛЛЕЛЬНО хореографии — вращение и есть индикатор загрузки.
    api("/auth/phone/verify", { method: "POST", body: { phone: phone, code: code } })
      .then(function (data) { otpResult = { ok: true, data: data }; })
      .catch(function (e) {
        otpResult = { ok: false, msg: e.message || "Не удалось" };
      })
      .then(function () {
        // reduced motion / фаза ожидания сама заметит результат; но если
        // ошибка пришла до конца spin — дадим reverse стартовать на границе фаз.
        if (otpResult && !otpResult.ok &&
            (otpPhase === "spinwait" || otpPhase === "spin")) {
          // ничего: фазовая машина проверит otpResult на границе
        }
      });

    if (otpReduced()) {
      // Без движения: просто ждём результат и мгновенно показываем состояние.
      var wait = setInterval(function () {
        if (otpResult === null) return;
        clearInterval(wait);
        if (otpResult.ok) { otpFinishSuccess(); }
        else { otpFinishError(); }
      }, 60);
      return;
    }

    setTimeout(function () {
      otpPhase = "explode";
      otpT0 = performance.now();
      otpRaf = requestAnimationFrame(otpFrame);
    }, 260);
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

  // ── единый аватар: смена/удаление прямо с сайта ─────────────────────────────
  function uploadAvatarFile(file) {
    var headers = {};
    var t = getToken();
    if (t) headers["Authorization"] = "Bearer " + t;
    var fd = new FormData();
    fd.append("image", file);
    return fetch(API + "/profile/avatar", {
      method: "POST",
      headers: headers,
      body: fd,
    }).then(function (r) {
      return r.text().then(function (x) {
        var d = x ? JSON.parse(x) : null;
        if (!r.ok) throw new Error((d && d.detail) || "Ошибка загрузки");
        return d;
      });
    });
  }
  // Выбрать фото и загрузить как единый аватар; затем обновить шапку и вызвать onDone.
  function changeAvatar(onDone) {
    if (!getToken()) return;
    var inp = document.createElement("input");
    inp.type = "file";
    inp.accept = "image/*";
    inp.style.display = "none";
    document.body.appendChild(inp);
    inp.addEventListener("change", function () {
      var f = inp.files && inp.files[0];
      if (inp.parentNode) inp.parentNode.removeChild(inp);
      if (!f) return;
      uploadAvatarFile(f)
        .then(function (user) {
          setSession(getToken(), user);
          refresh();
          if (typeof onDone === "function") onDone(user);
        })
        .catch(function (err) {
          window.alert(err.message || "Не удалось загрузить фото");
        });
    });
    inp.click();
  }
  function removeAvatar(onDone) {
    if (!getToken()) return;
    var headers = {};
    var t = getToken();
    if (t) headers["Authorization"] = "Bearer " + t;
    fetch(API + "/profile/avatar", { method: "DELETE", headers: headers })
      .then(function (r) {
        return r.text().then(function (x) {
          var d = x ? JSON.parse(x) : null;
          if (!r.ok) throw new Error((d && d.detail) || "Ошибка");
          return d;
        });
      })
      .then(function (user) {
        setSession(getToken(), user);
        refresh();
        if (typeof onDone === "function") onDone(user);
      })
      .catch(function (err) {
        window.alert(err.message || "Не удалось убрать фото");
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
    // Единый аватар экосистемы: показать/сменить/убрать с сайта.
    window.STAW.avatarUrl = avatarUrl;
    window.STAW.changeAvatar = changeAvatar;
    window.STAW.removeAvatar = removeAvatar;
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
