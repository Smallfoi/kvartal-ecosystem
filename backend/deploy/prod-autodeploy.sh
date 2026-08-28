#!/usr/bin/env bash
# МАТА — авто-деплой прод-ВМ (STANDALONE). Крон запускает раз в 2 минуты.
# ЗАЧЕМ ОТДЕЛЬНЫЙ ФАЙЛ: как и prod-deploy.sh — `yc --metadata-from-file` вырезает
# простые $-переменные ($LOCAL/$REMOTE) из запекаемого в cloud-init скрипта. Поэтому
# держим здесь и ставим на ВМ через prod-deploy.sh (копией из склонированного репо).
# При новом коммите в main: git reset --hard → пересобрать web/worker/beat + статику сайта.
set -uo pipefail
exec 9>/var/lock/mata-autodeploy.lock
flock -n 9 || exit 0                      # прошлый прогон ещё идёт — выходим
[ -f /opt/mata-deploy.done ] || exit 0    # первичный деплой ещё не закончился
cd /opt/mata || exit 0
git fetch origin main --quiet || exit 0
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)
[ "$LOCAL" = "$REMOTE" ] && exit 0        # нечего катить
echo "=== $(date -u) autodeploy $LOCAL -> $REMOTE ==="
git reset --hard origin/main
# Статика САЙТ МАТА → /opt/mata-site (bind-mount в nginx): синхронизируем содержимое ПО МЕСТУ
# (тот же inode), иначе rm -rf сорвёт монтирование и сайт отдаст 403/500.
mkdir -p /opt/mata-site
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete --exclude='*.md' --exclude='AGENTS.md' --exclude='Референсы' \
    /opt/mata/"САЙТ МАТА"/ /opt/mata-site/
else
  cp -rT /opt/mata/"САЙТ МАТА" /opt/mata-site
  find /opt/mata-site -maxdepth 1 -name '*.md' -delete 2>/dev/null || true
  rm -f /opt/mata-site/AGENTS.md 2>/dev/null || true
  rm -rf /opt/mata-site/"Референсы" 2>/dev/null || true
fi
cd /opt/mata/backend
cp nginx/mata.conf.example nginx/mata.conf
sed -i 's/api\.mata-store\.ru/api.mata-club.ru/g' nginx/mata.conf
# Пересобрать код (migrate+collectstatic — в команде web). timeout — чтобы зависание не держало flock.
timeout 360 docker compose -f docker-compose.prod.yml --env-file .env up -d --build web worker beat || true
timeout 120 docker compose -f docker-compose.prod.yml --env-file .env exec -T web python manage.py publish_legal || true
# nginx: перечитать конфиг (статика читается на каждый запрос — синк уже виден).
timeout 60 docker compose -f docker-compose.prod.yml --env-file .env exec -T nginx nginx -s reload 2>/dev/null \
  || timeout 120 docker compose -f docker-compose.prod.yml --env-file .env up -d nginx || true
echo "=== $(date -u) autodeploy done ==="
