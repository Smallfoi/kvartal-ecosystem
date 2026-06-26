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
# Ротация: удалить дампы старше KEEP_DAYS дней.
find "$DIR" -name 'staw_*.sql.gz' -mtime +"$KEEP_DAYS" -delete 2>/dev/null || true
