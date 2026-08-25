/**
 * Страница «Философия» — поведение, которого нет на главной.
 *
 *  - шапка: над фотогероем светлая, ниже уплотняется (как на главной);
 *  - параллакс фонов героя и манифеста;
 *  - манифест: строки зажигаются по мере прокрутки закреплённого экрана;
 *  - лента работ: тянется 1:1 за курсором, на отпускании — бросок с инерцией;
 *  - появление блоков — тот же IntersectionObserver, что на главной.
 *
 * Всё считаем в одном кадре (rAF) и трогаем только transform/opacity, чтобы
 * прокрутка оставалась гладкой. Уважаем prefers-reduced-motion.
 */
(function () {
  "use strict";

  var reduce =
    window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // ── Появление блоков ──────────────────────────────────────────────────────
  var revealItems = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    var revealObserver = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            revealObserver.unobserve(entry.target);
          }
        });
      },
      { rootMargin: "0px 0px -12% 0px", threshold: 0.12 }
    );
    revealItems.forEach(function (el, i) {
      el.style.setProperty("--delay", Math.min(i % 4, 3) * 90 + "ms");
      revealObserver.observe(el);
    });
  } else {
    revealItems.forEach(function (el) { el.classList.add("is-visible"); });
  }

  // ── Слоты: понять, поставил ли владелец фон ───────────────────────────────
  // Видео content.js кладёт слоем .staw-bg-layer, фото — inline-стилем. Класса,
  // общего для обоих случаев, нет, поэтому ставим свой: от него зависит,
  // прятать ли подсказку и показывать ли подпись кадра.
  var slots = [].slice.call(document.querySelectorAll(".phil-slot"));

  function syncSlot(el) {
    var hasImg = !!(el.style.backgroundImage && el.style.backgroundImage !== "none");
    var hasVid = !!el.querySelector(":scope > .staw-bg-layer");
    el.classList.toggle("staw-has-bg", hasImg || hasVid);
  }

  slots.forEach(syncSlot);

  if ("MutationObserver" in window) {
    var slotObserver = new MutationObserver(function (records) {
      records.forEach(function (r) { syncSlot(r.target); });
    });
    slots.forEach(function (el) {
      slotObserver.observe(el, { attributes: true, attributeFilter: ["style", "class"], childList: true });
    });
  }
  // Конструктор сообщает, что контент применён — пересверяем разом.
  window.addEventListener("staw-content-applied", function () { slots.forEach(syncSlot); });

  // ── Скролл: шапка, параллакс, строки манифеста ────────────────────────────
  var header = document.querySelector("[data-header]");
  var hero = document.querySelector(".hero");
  var parallax = [].slice.call(document.querySelectorAll("[data-parallax]"));
  var manifest = document.querySelector("[data-manifest]");
  var lines = [].slice.call(document.querySelectorAll("[data-line]"));
  var ticking = false;

  function frame() {
    ticking = false;
    var y = window.scrollY || 0;

    if (header) {
      // Пока герой на экране — шапка прозрачная и светлая, дальше как на главной.
      var heroH = hero ? hero.offsetHeight : 0;
      header.classList.toggle("is-scrolled", y > Math.max(8, heroH - 90));
    }

    if (!reduce) {
      parallax.forEach(function (el) {
        var box = el.getBoundingClientRect();
        if (box.bottom < -200 || box.top > window.innerHeight + 200) return;
        var mid = box.top + box.height / 2 - window.innerHeight / 2;
        var k = parseFloat(el.getAttribute("data-parallax")) || 0.1;
        // Увеличенный кадр — чтобы при сдвиге не показались края слоя.
        var s = parseFloat(el.getAttribute("data-parallax-scale")) || 0;
        el.style.transform = "translate3d(0," + (-mid * k).toFixed(2) + "px,0)"
          + (s ? " scale(" + s + ")" : "");
      });
    }

    if (manifest && lines.length) {
      var box2 = manifest.getBoundingClientRect();
      var total = manifest.offsetHeight - window.innerHeight;
      var progress = total > 0 ? Math.min(1, Math.max(0, -box2.top / total)) : 0;
      // Первая строка горит сразу, дальше — по мере прокрутки.
      var active = Math.floor(progress * (lines.length + 0.4));
      lines.forEach(function (line, i) { line.classList.toggle("is-on", i <= active); });
    }
  }

  function onScroll() {
    if (!ticking) {
      ticking = true;
      window.requestAnimationFrame(frame);
    }
  }

  window.addEventListener("scroll", onScroll, { passive: true });
  window.addEventListener("resize", onScroll);
  frame();

  // ── Мобильное меню ────────────────────────────────────────────────────────
  var toggle = document.querySelector("[data-nav-toggle]");
  var mobile = document.querySelector("[data-mobile-nav]");
  if (toggle && mobile) {
    toggle.addEventListener("click", function () {
      var open = mobile.classList.toggle("is-open");
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
    });
    mobile.querySelectorAll("[data-mobile-link]").forEach(function (link) {
      link.addEventListener("click", function () {
        mobile.classList.remove("is-open");
        toggle.setAttribute("aria-expanded", "false");
      });
    });
  }

  // ── Лента работ ───────────────────────────────────────────────────────────
  var rail = document.querySelector("[data-rail]");
  if (!rail) return;

  function reels() {
    return [].filter.call(rail.children, function (el) {
      return el.classList && el.classList.contains("phil-reel");
    });
  }

  function nearest(center) {
    var best = null;
    var bestDistance = Infinity;
    reels().forEach(function (el) {
      var c = el.offsetLeft + el.offsetWidth / 2;
      var d = Math.abs(c - center);
      if (d < bestDistance) { bestDistance = d; best = el; }
    });
    return best;
  }

  function markFocus() {
    var focused = nearest(rail.scrollLeft + rail.clientWidth / 2);
    reels().forEach(function (el) { el.classList.toggle("is-focus", el === focused); });
  }

  var focusTick = false;
  rail.addEventListener(
    "scroll",
    function () {
      if (focusTick) return;
      focusTick = true;
      window.requestAnimationFrame(function () { focusTick = false; markFocus(); });
    },
    { passive: true }
  );
  markFocus();

  var dragging = false;
  var startX = 0;
  var startScroll = 0;
  var history = [];

  rail.addEventListener("pointerdown", function (e) {
    if (e.pointerType === "touch") return; // на тач-экранах хватает родной прокрутки
    dragging = true;
    rail.setPointerCapture(e.pointerId);
    rail.classList.add("is-dragging");
    startX = e.clientX;
    startScroll = rail.scrollLeft;
    history = [{ x: e.clientX, t: performance.now() }];
  });

  rail.addEventListener("pointermove", function (e) {
    if (!dragging) return;
    rail.scrollLeft = startScroll - (e.clientX - startX); // 1:1 за курсором
    history.push({ x: e.clientX, t: performance.now() });
    if (history.length > 6) history.shift();
  });

  function release(e) {
    if (!dragging) return;
    dragging = false;
    rail.classList.remove("is-dragging");
    try { rail.releasePointerCapture(e.pointerId); } catch (err) {}

    var first = history[0];
    var last = history[history.length - 1];
    var dt = first && last ? last.t - first.t : 0;
    var velocity = dt > 0 ? ((last.x - first.x) / dt) * 1000 : 0; // px/с

    // Проекция инерции: куда лента доехала бы при обычном замедлении.
    var decel = 0.998;
    var projected = rail.scrollLeft - (velocity / 1000) * decel / (1 - decel);
    var target = nearest(projected + rail.clientWidth / 2);
    if (!target) return;

    rail.scrollTo({
      left: target.offsetLeft + target.offsetWidth / 2 - rail.clientWidth / 2,
      behavior: reduce ? "auto" : "smooth"
    });
  }

  rail.addEventListener("pointerup", release);
  rail.addEventListener("pointercancel", release);
})();
