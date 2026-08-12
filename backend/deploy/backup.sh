#!/usr/bin/env bash
# Бэкап прод-БД STAW (PostgreSQL/PostGIS) через pg_dump.
# Запускать НА СЕРВЕРЕ из каталога backend/:  ./deploy/backup.sh
# Баллы = деньги → бэкап обязателен; повесить на cron (см. docs/DEPLOY.md).
set -euo pipefail

cd "$(dirname "$0")/.."  # → backend/
[ -f .env ] || { echo "Нет .env (см. .env.prod.example)"; exit 1; }
set -a; . ./.env; set +a   # загрузить POSTGRES_USER/DB и пр.

COMPOSE="docker compose -f docker-compose.prod.yml --env-file .env"
DIR="${BACKUP_DIR:-backups}"
KEEP_DAYS="${BACKUP_KEEP_DAYS:-14}"
mkdir -p "$DIR"

TS=$(date +%Y%m%d_%H%M%S)
OUT="$DIR/staw_${TS}.sql.gz"

echo "Бэкап БД '${POSTGRES_DB}' → $OUT"
$COMPOSE exec -T db pg_dump -U "${POSTGRES_USER}" "${POSTGRES_DB}" | gzip > "$OUT"

# Проверка, что дамп непустой (защита от «успешного» пустого бэкапа).
SIZE=$(gzip -dc "$OUT" | head -c 200000 | wc -c)
[ "$SIZE" -gt 1000 ] || { echo "ОШИБКА: дамп подозрительно мал — проверь БД"; exit 1; }

echo "Готово: $(du -h "$OUT" | cut -f1)"

# ── Выгрузка в объектное хранилище ────────────────────────────────────────────
# Дамп рядом с БД на том же диске — это НЕ бэкап: диск умрёт вместе с обоими.
# Заливаем в Yandex Object Storage подписью SigV4 средствами curl (без доп. пакетов).
S3_BUCKET="${BACKUP_S3_BUCKET:-}"
if [ -z "$S3_BUCKET" ]; then
  echo "ВНИМАНИЕ: BACKUP_S3_BUCKET не задан — дамп остался ТОЛЬКО на диске сервера."
else
  # Ключи по умолчанию — те же, что у медиа (обычно один сервисный аккаунт).
  S3_KEY="${BACKUP_S3_ACCESS_KEY:-${MEDIA_S3_ACCESS_KEY:-}}"
  S3_SECRET="${BACKUP_S3_SECRET_KEY:-${MEDIA_S3_SECRET_KEY:-}}"
  S3_ENDPOINT="${BACKUP_S3_ENDPOINT:-${MEDIA_S3_ENDPOINT:-https://storage.yandexcloud.net}}"
  S3_REGION="${BACKUP_S3_REGION:-${MEDIA_S3_REGION:-ru-central1}}"
  [ -n "$S3_KEY" ] && [ -n "$S3_SECRET" ] || {
    echo "ОШИБКА: BACKUP_S3_BUCKET задан, но ключи доступа пусты"; exit 1; }

  DEST="${S3_ENDPOINT%/}/${S3_BUCKET}/db/$(basename "$OUT")"
  echo "Выгрузка → $DEST"
  CODE=$(curl -sS -o /dev/null -w '%{http_code}' \
           --aws-sigv4 "aws:amz:${S3_REGION}:s3" \
           --user "${S3_KEY}:${S3_SECRET}" \
           --upload-file "$OUT" "$DEST") || CODE="000"
  [ "$CODE" = "200" ] || { echo "ОШИБКА выгрузки в S3: HTTP $CODE"; exit 1; }
  echo "Выгружено в бакет ${S3_BUCKET}."
fi

# Ротация ЛОКАЛЬНЫХ дампов старше KEEP_DAYS дней (в бакете — политика жизненного цикла).
find "$DIR" -name 'staw_*.sql.gz' -mtime +"$KEEP_DAYS" -delete 2>/dev/null || true
