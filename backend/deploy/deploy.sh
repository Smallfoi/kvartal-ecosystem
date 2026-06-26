#!/usr/bin/env bash
# Деплой/обновление прод STAW. Запуск НА СЕРВЕРЕ из backend/:  ./deploy/deploy.sh
# Идемпотентно: бэкап → сборка/миграции → smoke-тест. Откат — см. docs/DEPLOY.md.
set -euo pipefail

cd "$(dirname "$0")/.."  # → backend/
[ -f .env ] || { echo "Нет .env. Скопируй .env.prod.example → .env и заполни."; exit 1; }
COMPOSE="docker compose -f docker-compose.prod.yml --env-file .env"

echo "[1/3] Бэкап БД перед деплоем..."
./deploy/backup.sh || echo "  (БД ещё нет — похоже первый деплой, пропускаю)"

echo "[2/3] Сборка и запуск (web сам: migrate → collectstatic → gunicorn)..."
$COMPOSE up -d --build

echo "[3/3] Жду старта и проверяю..."
sleep 8
./deploy/smoke.sh
echo "✅ Деплой завершён ($(git rev-parse --short HEAD 2>/dev/null || echo '?'))."
