#!/usr/bin/env bash
# Разовая доводка прода после re-run деплоя (rm -rf /opt/mata стёр сертификаты TLS,
# nginx падает без них → сайт/API 000). Делает: (1) перевыпуск TLS + подъём nginx;
# (2) ставит авто-деплой (крон). Запуск на ВМ: sudo bash /tmp/fix.sh
set -uo pipefail
cd /opt/mata/backend

echo "== 1/2 Перевыпуск TLS + подъём nginx (сертификаты стёрлись при re-clone) =="
# tls.sh issue: остановит nginx, certbot выпустит сертификат (нужен порт 80), установит, поднимет nginx.
./deploy/tls.sh issue || echo ">>> TLS issue не удался — см. вывод выше (возможно, лимит выпуска)."

echo ""
echo "== 2/2 Авто-деплой + краны =="
curl -fsSL https://raw.githubusercontent.com/Smallfoi/mata-ecosystem/main/backend/deploy/prod-autodeploy.sh -o /opt/prod-autodeploy.sh
chmod +x /opt/prod-autodeploy.sh
( crontab -l 2>/dev/null | grep -v 'prod-autodeploy\|mata-autodeploy\|mata-tls\|tls.sh renew\|backup.sh' ; \
  echo "*/2 * * * * /opt/prod-autodeploy.sh >> /var/log/mata-autodeploy.log 2>&1" ; \
  echo "0 3 * * 1 cd /opt/mata/backend && ./deploy/tls.sh renew >> /var/log/mata-tls.log 2>&1" ; \
  echo "0 4 * * * cd /opt/mata/backend && ./deploy/backup.sh >> /var/log/mata-backup.log 2>&1" ) | crontab -

echo ""
echo "=== ИТОГ ==="
docker compose -f docker-compose.prod.yml --env-file .env ps --format '{{.Name}} {{.Status}}' 2>/dev/null | grep nginx || echo "nginx: статус не получен"
crontab -l 2>/dev/null | grep -q prod-autodeploy && echo "крон авто-деплоя: OK" || echo "крон: НЕ поставился"
echo "проверь сайт: https://mata-club.ru  и  https://api.mata-club.ru/v1/health"
