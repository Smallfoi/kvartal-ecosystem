/**
 * Юр-документы из общего backend (/legal/documents) → модалка по ссылкам [data-legal].
 * Тексты заполняет юрист в админке (Legal → LegalDocument). При офлайн/нет API —
 * показываем понятную заглушку, сайт не ломается.
 */
(function () {
  "use strict";

  var host = location.hostname;
  var isDev = host === "localhost" || host === "127.0.0.1" || host === "";
  var PROD_API = "https://api.mata-club.ru/v1";
  var API =
    (typeof window !== "undefined" && window.STAW_API_BASE) ||
    (isDev ? "http://127.0.0.1:8000/v1" : PROD_API);

  var modal = document.querySelector("[data-lg-modal]");
  var cache = null;

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  // Тело документов хранится как Markdown. Рендерим в безопасный HTML: текст
  // экранируется (esc), добавляются только «белые» теги. Иначе на сайте была бы
  // видна сырая разметка (##, **, бэктики, |таблицы|) — как обычный текст.
  function inline(s) {
    s = esc(s);
    s = s.replace(/\[([^\]]+)\]\([^)]*\)/g, "$1"); // ссылки → просто текст
    s = s.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
    s = s.replace(/`([^`]+)`/g, "$1");             // бэктики убираем (реквизиты и т.п.)
    s = s.replace(/(^|[^*])\*([^*]+)\*(?!\*)/g, "$1<em>$2</em>");
    return s;
  }
  function isSep(r) { return /^[\s:|-]+$/.test(r) && r.indexOf("-") > -1; }
  function cells(r) {
    return r.replace(/^\||\|$/g, "").split("|").map(function (c) { return c.trim(); });
  }
  function renderTable(rows) {
    var out = "<table>", start = 0, header = null;
    if (rows.length >= 2 && isSep(rows[1])) { header = rows[0]; start = 2; }
    if (header) {
      out += "<thead><tr>" + cells(header).map(function (c) { return "<th>" + inline(c) + "</th>"; }).join("") + "</tr></thead>";
    }
    out += "<tbody>";
    for (var j = start; j < rows.length; j++) {
      if (isSep(rows[j])) continue;
      out += "<tr>" + cells(rows[j]).map(function (c) { return "<td>" + inline(c) + "</td>"; }).join("") + "</tr>";
    }
    return out + "</tbody></table>";
  }
  function mdToHtml(md) {
    var lines = String(md).replace(/\r\n/g, "\n").split("\n");
    var out = [], i = 0;
    while (i < lines.length) {
      var t = lines[i].trim();
      if (t === "") { i++; continue; }
      if (/^(-{3,}|\*{3,}|_{3,})$/.test(t)) { out.push("<hr>"); i++; continue; }
      var h = /^(#{1,6})\s+(.*)$/.exec(t);
      if (h) { var lvl = Math.min(h[1].length + 1, 6); out.push("<h" + lvl + ">" + inline(h[2]) + "</h" + lvl + ">"); i++; continue; }
      if (/^>\s?/.test(t)) { out.push("<blockquote>" + inline(t.replace(/^>\s?/, "")) + "</blockquote>"); i++; continue; }
      if (t.indexOf("|") > -1) {
        var rows = [];
        while (i < lines.length && lines[i].trim().indexOf("|") > -1) { rows.push(lines[i].trim()); i++; }
        out.push(renderTable(rows));
        continue;
      }
      if (/^[-*]\s+/.test(t)) {
        var items = [];
        while (i < lines.length && /^[-*]\s+/.test(lines[i].trim())) {
          items.push("<li>" + inline(lines[i].trim().replace(/^[-*]\s+/, "")) + "</li>"); i++;
        }
        out.push("<ul>" + items.join("") + "</ul>");
        continue;
      }
      var para = [];
      while (i < lines.length) {
        var l = lines[i].trim();
        if (l === "" || /^(#{1,6}\s|>|[-*]\s|\|)/.test(l) || /^(-{3,}|\*{3,}|_{3,})$/.test(l)) break;
        para.push(l); i++; // сырые строки; inline — после склейки (иначе **жирный** через строку не ловится)
      }
      out.push("<p>" + inline(para.join(" ")) + "</p>");
    }
    return out.join("");
  }

  // Загрузка и разбор — общие для модалки и для отдельной страницы документа
  // (/legal/privacy и т.п.). Одна реализация markdown на оба места.
  window.STAW_LEGAL = { md: mdToHtml, docs: getDocs };

  if (!modal) return;   // страница документа рисует себя сама, модалка ей не нужна

  function show(doc) {
    modal.querySelector("[data-lg-title]").textContent = doc.title || "Документ";
    modal.querySelector("[data-lg-meta]").textContent = doc.version ? "Версия " + doc.version : "";
    // Убираем первый заголовок из тела (# Название) — он дублирует заголовок окна.
    var body = String(doc.body || "").replace(/^﻿?\s*#{1,6}[^\n]*\r?\n?/, "");
    modal.querySelector("[data-lg-body]").innerHTML = mdToHtml(body);
  }

  function getDocs() {
    if (cache) return Promise.resolve(cache);
    return fetch(API + "/legal/documents")
      .then(function (r) { return r.ok ? r.json() : Promise.reject(); })
      .then(function (d) { cache = d; return d; });
  }

  // Блокировку скролла фона делает motion.js (Lenis-совместимо): при открытии
  // оверлея он стопит Lenis, а колесо внутри окна идёт нативно через
  // data-lenis-prevent. Модалка .lg-modal подключена к этому механизму (см. motion.js),
  // поэтому здесь position:fixed НЕ нужен (он дрался с Lenis и давал прыжок при закрытии).
  function open(type) {
    show({ title: "Загрузка…", body: "", version: "" });
    modal.classList.add("is-open");
    modal.setAttribute("aria-hidden", "false");
    getDocs()
      .then(function (docs) {
        var doc = (docs || []).filter(function (d) { return d.type === type; })[0];
        show(
          doc || {
            title: "Документ готовится",
            body: "Текст этого документа ещё не опубликован в админке.",
            version: "",
          },
        );
      })
      .catch(function () {
        show({ title: "Не удалось загрузить", body: "Проверьте подключение к интернету.", version: "" });
      });
  }

  function close() {
    modal.classList.remove("is-open");
    modal.setAttribute("aria-hidden", "true");
  }

  document.addEventListener("click", function (e) {
    var link = e.target.closest("[data-legal]");
    if (!link) return;
    e.preventDefault();
    open(link.getAttribute("data-legal"));
  });
  modal.querySelectorAll("[data-lg-close]").forEach(function (b) {
    b.addEventListener("click", close);
  });
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && modal.classList.contains("is-open")) close();
  });
})();
