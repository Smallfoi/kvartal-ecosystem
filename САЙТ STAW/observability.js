// observability.js — единый журнал ошибок сайта STAW → GlitchTip (Sentry-совместимый).
//
// Ошибки JS сайта (window.onerror + unhandledrejection + ручной window.stawCapture)
// уходят в ТОТ ЖЕ GlitchTip, что и backend и приложения (Квартал/Store) — единый
// журнал ошибок всей экосистемы (D-32). Без внешних зависимостей.
//
// DSN — это ПУБЛИЧНЫЙ ключ (по дизайну Sentry/GlitchTip его можно держать в клиенте:
// он позволяет только ОТПРАВЛЯТЬ события, не читать их). Prod-DSN задать одним из:
//   - window.STAW_SENTRY_DSN = "https://<key>@<glitchtip-host>/<project>"  ДО подключения;
//   - либо заполнить PROD_DSN ниже при запуске.
(function () {
  "use strict";
  try {
    var isDev =
      location.hostname === "localhost" || location.hostname === "127.0.0.1";
    var PROD_DSN = ""; // ← заполнить при проде (публичный DSN боевого GlitchTip)
    var DSN =
      (typeof window !== "undefined" && window.STAW_SENTRY_DSN) ||
      (isDev
        ? "http://0a767332bdf84e14b8f7c76eacf861ab@localhost:8080/4" // проект «site»
        : PROD_DSN);
    if (!DSN) return; // без DSN — тихий no-op

    // Разбор DSN: <scheme>://<key>@<host[:port]>/<project>
    var m = /^(https?):\/\/([^@]+)@([^/]+)\/(.+)$/.exec(DSN);
    if (!m) return;
    var INGEST =
      m[1] +
      "://" +
      m[3] +
      "/api/" +
      m[4] +
      "/store/?sentry_key=" +
      m[2] +
      "&sentry_version=7";

    var ENV = isDev ? "dev" : "prod";
    var sent = 0;
    var MAX = 25; // защита от флуда за сессию
    var seen = {};

    function uuid() {
      return "xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx".replace(/[xy]/g, function (c) {
        var r = (Math.random() * 16) | 0;
        return (c === "x" ? r : (r & 0x3) | 0x8).toString(16);
      });
    }

    function parseFrames(stack) {
      var frames = [];
      (stack || "")
        .split("\n")
        .slice(0, 30)
        .forEach(function (line) {
          var f =
            /(?:at\s+)?(.*?)\s*\(?(https?:\/\/[^\s)]+):(\d+):(\d+)\)?/.exec(line);
          if (f) {
            frames.push({
              function: (f[1] || "?").trim() || "?",
              filename: f[2],
              lineno: +f[3],
              colno: +f[4],
            });
          }
        });
      return frames.reverse(); // Sentry ждёт фреймы «снизу вверх»
    }

    function send(type, value, stack, level) {
      if (sent >= MAX) return;
      var key = type + "|" + value;
      if (seen[key]) return; // дедуп одинаковых
      seen[key] = 1;
      sent++;
      var frames = parseFrames(stack);
      var event = {
        event_id: uuid(),
        timestamp: new Date().toISOString(),
        platform: "javascript",
        level: level || "error",
        logger: "site",
        environment: ENV,
        release: "site@" + (window.STAW_SITE_VERSION || "dev"),
        exception: {
          values: [
            {
              type: type || "Error",
              value: String(value == null ? "" : value).slice(0, 1000),
              stacktrace: frames.length ? { frames: frames } : undefined,
            },
          ],
        },
        tags: { source: "site" },
        request: {
          url: location.href,
          headers: { "User-Agent": navigator.userAgent },
        },
      };
      try {
        fetch(INGEST, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(event),
          mode: "cors",
          keepalive: true,
        }).catch(function () {});
      } catch (e) {
        /* репортер НИКОГДА не должен ломать сайт */
      }
    }

    window.addEventListener("error", function (e) {
      if (e && e.error) {
        send(e.error.name || "Error", e.error.message || e.message, e.error.stack);
      } else if (e && e.message) {
        send("Error", e.message, (e.filename || "") + ":" + (e.lineno || 0));
      }
    });

    window.addEventListener("unhandledrejection", function (e) {
      var r = e && e.reason;
      if (r && r.stack) {
        send(r.name || "UnhandledRejection", r.message || String(r), r.stack);
      } else {
        send("UnhandledRejection", String(r), "");
      }
    });

    // Ручной хук для нашего кода: window.stawCapture(errOrMessage)
    window.stawCapture = function (err) {
      if (err && err.stack) {
        send(err.name || "Error", err.message || String(err), err.stack);
      } else {
        send("Error", String(err), "");
      }
    };
  } catch (e) {
    /* инициализация репортера не должна ронять страницу */
  }
})();
