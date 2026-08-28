#!/usr/bin/env bash
# Разовая доводка прода после re-run деплоя: (1) пересоздать nginx (после rm -rf он завис
# на мёртвой папке → сайт 403); (2) поставить авто-деплой (крон), который не поднялся.
# Запуск на ВМ: sudo bash /tmp/fix.sh
set -euo pipefail
cd /opt/mata/backend

echo "== 1/2 Пересоздаю nginx (вернёт сайт 403 → 200) =="
docker compose -f docker-compose.prod.yml --env-file .env up -d --force-recreate nginx

echo "== 2/2 Ставлю авто-деплой + краны =="
# Скрипт качаем напрямую (curl → переменные целы, в отличие от запечённого cloud-init).
curl -fsSL https://raw.githubusercontent.com/Smallfoi/mata-ecosystem/main/backend/deploy/prod-autodeploy.sh -o /opt/prod-autodeploy.sh
chmod +x /opt/prod-autodeploy.sh
( crontab -l 2>/dev/null | grep -v 'prod-autodeploy\|mata-autodeploy\|mata-tls\|tls.sh renew\|backup.sh' ; \
  echo "*/2 * * * * /opt/prod-autodeploy.sh >> /var/log/mata-autodeploy.log 2>&1" ; \
  echo "0 3 * * 1 cd /opt/mata/backend && ./deploy/tls.sh renew >> /var/log/mata-tls.log 2>&1" ; \
  echo "0 4 * * * cd /opt/mata/backend && ./deploy/backup.sh >> /var/log/mata-backup.log 2>&1" ) | crontab -

echo ""
echo "=== ГОТОВО ==="
crontab -l | grep -q prod-autodeploy && echo "крон авто-деплоя: OK" || echo "крон: НЕ поставился (сообщи Claude)"
echo "проверь сайт: https://mata-club.ru"
