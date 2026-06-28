/**
 * Юр-документы из общего backend (/legal/documents) → модалка по ссылкам [data-legal].
 * Тексты заполняет юрист в админке (Legal → LegalDocument). При офлайн/нет API —
 * показываем понятную заглушку, сайт не ломается.
 */
(function () {
  "use strict";

  var host = location.hostname;
  var isDev = host === "localhost" || host === "127.0.0.1" || host === "";
  var PROD_API = "https://api.staw.ru/v1";
  var API =
    (typeof window !== "undefined" && window.STAW_API_BASE) ||
    (isDev ? "http://127.0.0.1:8000/v1" : PROD_API);

  var modal = document.querySelector("[data-lg-modal]");
  if (!modal) return;
  var cache = null;

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  function show(doc) {
    modal.querySelector("[data-lg-title]").textContent = doc.title || "Документ";
    modal.querySelector("[data-lg-meta]").textContent = doc.version ? "Версия " + doc.version : "";
    modal.querySelector("[data-lg-body]").innerHTML = esc(String(doc.body || "")).replace(/\n/g, "<br>");
  }

  function getDocs() {
    if (cache) return Promise.resolve(cache);
    return fetch(API + "/legal/documents")
      .then(function (r) { return r.ok ? r.json() : Promise.reject(); })
      .then(function (d) { cache = d; return d; });
  }

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
