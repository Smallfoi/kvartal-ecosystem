#!/usr/bin/env bash
# Smoke-тест прод после деплоя: дёргаем ключевые эндпоинты ИЗНУТРИ web-контейнера
# (не зависит от nginx/TLS/публикации портов). Возврат !=0 — деплой плохой.
set -euo pipefail

cd "$(dirname "$0")/.."  # → backend/
COMPOSE="docker compose -f docker-compose.prod.yml --env-file .env"

_get() {  # _get <path> → печатает первые 500 байт ответа (или ERR:...)
  $COMPOSE exec -T web python - "$1" <<'PY'
import sys, urllib.request
try:
    # Прод форсит HTTPS (SECURE_SSL_REDIRECT) — шлём тот же заголовок, что и nginx,
    # иначе прямой запрос к gunicorn получит 301 на https и упадёт.
    req = urllib.request.Request(
        "http://127.0.0.1:8000" + sys.argv[1],
        headers={"X-Forwarded-Proto": "https"},
    )
    r = urllib.request.urlopen(req, timeout=5)
    sys.stdout.write(r.read(500).decode("utf-8", "replace"))
except Exception as e:
    sys.stdout.write("ERR:" + str(e))
PY
}

check() {  # check <path> <ожидаемая-подстрока>
  local body; body=$(_get "$1")
  if printf '%s' "$body" | grep -q -- "$2"; then
    echo "  OK   $1"
  else
    echo "  FAIL $1  → ${body:0:120}"; return 1
  fi
}

echo "Smoke-тест прод:"
fail=0
check /v1/health '"status":"ok"' || fail=1
check /v1/categories '[' || fail=1
check /v1/banners '[' || fail=1
if [ "$fail" = 0 ]; then echo "✅ Smoke OK"; else echo "❌ Smoke ПРОВАЛЕН"; exit 1; fi
