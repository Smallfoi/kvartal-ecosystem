#!/usr/bin/env bash
# Smoke-тест прод после деплоя: дёргаем ключевые эндпоинты ИЗНУТРИ web-контейнера
# (не зависит от nginx/TLS/публикации портов). Возврат !=0 — деплой плохой.
set -euo pipefail

cd "$(dirname "$0")/.."  # → backend/
[ -f .env ] || { echo "Нет .env (см. .env.prod.example)"; exit 1; }
set -a; . ./.env; set +a
COMPOSE="docker compose -f docker-compose.prod.yml --env-file .env"

# Стучимся внутрь контейнера по 127.0.0.1, но Host шлём первый из DJANGO_ALLOWED_HOSTS:
# в проде там только домен (api.staw.ru), и запрос с Host=127.0.0.1 Django отвергнет
# как DisallowedHost (400) — smoke падал бы на исправно работающем сервере.
HOST_HDR=$(printf '%s' "${DJANGO_ALLOWED_HOSTS:-}" | cut -d, -f1 | tr -d ' ')
case "$HOST_HDR" in ""|"*") HOST_HDR="127.0.0.1" ;; esac

_get() {  # _get <path> → печатает первые 500 байт ответа (или ERR:...)
  $COMPOSE exec -T web python - "$1" "$HOST_HDR" <<'PY'
import sys, urllib.request
try:
    # Прод форсит HTTPS (SECURE_SSL_REDIRECT) — шлём тот же заголовок, что и nginx,
    # иначе прямой запрос к gunicorn получит 301 на https и упадёт.
    req = urllib.request.Request(
        "http://127.0.0.1:8000" + sys.argv[1],
        headers={"X-Forwarded-Proto": "https", "Host": sys.argv[2]},
    )
    r = urllib.request.urlopen(req, timeout=5)
    sys.stdout.write(r.read(500).decode("utf-8", "replace"))
except Exception as e:
    sys.stdout.write("ERR:" + str(e))
PY
}

check() {  # check <path> <ожидаемая-подстрока>
  local body; body=$(_get "$1")
  # -F: сравниваем как ПОДСТРОКУ, не регулярку — иначе ожидаемое '[' (JSON-массив)
  # grep считает незакрытым классом символов и падает «Invalid regular expression».
  if printf '%s' "$body" | grep -qF -- "$2"; then
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

# Фоновые задачи: без worker/beat молча перестают выполняться чистка данных с
# истёкшим сроком хранения (152-ФЗ), парсер афиши «Стартов» и рассылки —
# по API это никак не видно, поэтому проверяем отдельно.
running=$($COMPOSE ps --services --filter status=running 2>/dev/null || true)
for svc in worker beat; do
  if printf '%s\n' "$running" | grep -qx "$svc"; then
    echo "  OK   сервис $svc"
  else
    echo "  FAIL сервис $svc не запущен"; fail=1
  fi
done

if [ "$fail" = 0 ]; then echo "✅ Smoke OK"; else echo "❌ Smoke ПРОВАЛЕН"; exit 1; fi
