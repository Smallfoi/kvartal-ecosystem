/**
 * Страница одного юридического документа: /legal/?doc=privacy
 *
 * Зачем отдельная страница, если документы уже открываются модалкой на главной:
 * наружу нужна ССЫЛКА. Партнёрские программы (Garmin, Suunto) и проверка
 * приложения в App Store просят рабочий адрес политики конфиденциальности,
 * а модалка адреса не имеет.
 *
 * Загрузку и разбор markdown берём из legal.js (window.STAW_LEGAL) — вторая
 * реализация того же самого у нас уже однажды разъехалась с первой.
 */
(function () {
  "use strict";

  var L = window.STAW_LEGAL;
  var titleEl = document.querySelector("[data-doc-title]");
  var metaEl = document.querySelector("[data-doc-meta]");
  var bodyEl = document.querySelector("[data-doc-body]");
  var listEl = document.querySelector("[data-doc-list]");
  if (!titleEl || !bodyEl) return;

  // Тип документа: ?doc=privacy, а если параметра нет — политика
  // конфиденциальности: именно на неё чаще всего ведут ссылки снаружи.
  var type = new URLSearchParams(location.search).get("doc") || "privacy";
  if (!/^[a-z_]{2,30}$/.test(type)) type = "privacy";

  function fail(text) {
    titleEl.textContent = "Документ недоступен";
    metaEl.textContent = "";
    bodyEl.innerHTML = "<p>" + text + "</p>";
  }

  if (!L || !L.docs || !L.md) {
    fail("Не удалось загрузить список документов.");
    return;
  }

  L.docs()
    .then(function (docs) {
      docs = docs || [];
      var doc = docs.filter(function (d) { return d.type === type; })[0];

      if (!doc) {
        fail("Такого документа нет. Выберите из списка ниже.");
      } else {
        document.title = doc.title + " — МАТА";
        titleEl.textContent = doc.title;
        metaEl.textContent = doc.version ? "Редакция " + doc.version : "";
        // Первый заголовок убираем: он дублирует заголовок страницы.
        bodyEl.innerHTML = L.md(String(doc.body || "").replace(/^﻿?\s*#{1,6}[^\n]*\r?\n?/, ""));
      }

      if (!listEl) return;
      listEl.innerHTML = docs
        .map(function (d) {
          var here = d.type === type ? ' aria-current="page"' : "";
          return '<li><a href="?doc=' + encodeURIComponent(d.type) + '"' + here + ">" + d.title + "</a></li>";
        })
        .join("");
    })
    .catch(function () {
      fail("Не удалось загрузить документ. Проверьте подключение к интернету.");
    });
})();
