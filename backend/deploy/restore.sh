#!/usr/bin/env bash
# Восстановление прод-БД STAW из бэкапа backup.sh.
# ВНИМАНИЕ: перезаписывает текущую БД! Запуск:  ./deploy/restore.sh backups/mata_YYYYMMDD_HHMMSS.sql.gz
set -euo pipefail

cd "$(dirname "$0")/.."  # → backend/
FILE="${1:-}"
[ -n "$FILE" ] && [ -f "$FILE" ] || { echo "Использование: ./deploy/restore.sh <файл.sql.gz>"; exit 1; }
[ -f .env ] || { echo "Нет .env"; exit 1; }
set -a; . ./.env; set +a

COMPOSE="docker compose -f docker-compose.prod.yml --env-file .env"

echo "ВОССТАНОВЛЕНИЕ перезапишет БД '${POSTGRES_DB}' из $FILE"
read -r -p "Точно продолжить? (введите 'yes'): " ans
[ "$ans" = "yes" ] || { echo "Отменено."; exit 1; }

# Сначала контрольный бэкап текущего состояния — на случай отката отката.
echo "Контрольный бэкап текущей БД перед восстановлением..."
./deploy/backup.sh || echo "(пропускаю контрольный бэкап)"

echo "Восстанавливаю..."
# Зашифрованный дамп (.enc) расшифровываем на лету — на диск открытым не кладём.
case "$FILE" in
  *.enc)
    [ -n "${BACKUP_ENCRYPT_PASSPHRASE:-}" ] || {
      echo "Файл зашифрован, а BACKUP_ENCRYPT_PASSPHRASE не задан в .env"; exit 1; }
    openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000       -in "$FILE" -pass env:BACKUP_ENCRYPT_PASSPHRASE       | gzip -dc | $COMPOSE exec -T db psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}"
    ;;
  *)
    gzip -dc "$FILE" | $COMPOSE exec -T db psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}"
    ;;
esac
echo "Готово. Проверь приложение и /v1/health."
