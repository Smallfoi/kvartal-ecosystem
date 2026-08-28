#!/usr/bin/env bash
# МАТА backend — прод-деплой (STANDALONE).
# ЗАЧЕМ ОТДЕЛЬНЫЙ ФАЙЛ: `yc compute instance create --metadata-from-file` вырезает
# простые $-переменные ($IAM/$LB_SECRET_ID/$DBDEV/$k...) из ЗАПЕКАЕМОГО в cloud-init
# скрипта (оставляя только $(...)), из-за чего ломались Lockbox и монтирование диска.
# Этот скрипт ВМ качает через curl (переменные целостны) и запускает — без запекания.
# Без set -x — чтобы секреты не попали в лог/serial.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Надёжная установка пакетов (apt-lock на свежей ВМ держит apt-daily — ждём до 10 мин).
for i in 1 2 3 4 5 6; do
  apt-get -o DPkg::Lock::Timeout=600 update -y && \
  apt-get -o DPkg::Lock::Timeout=600 install -y docker.io docker-compose-v2 git rsync && break
  echo "apt attempt $i failed — retrying in 20s..."; sleep 20
done
command -v docker >/dev/null || { echo "FATAL: docker не установился после ретраев"; exit 1; }
systemctl enable --now docker
usermod -aG docker ubuntu || true

rm -rf /opt/mata && git clone --depth 1 https://github.com/Smallfoi/mata-ecosystem.git /opt/mata
# Статика САЙТ МАТА → чистый путь /opt/mata-site (без внутренних *.md/Референсы).
rm -rf /opt/mata-site && cp -r /opt/mata/"САЙТ МАТА" /opt/mata-site
rm -f /opt/mata-site/*.md /opt/mata-site/AGENTS.md 2>/dev/null || true
rm -rf /opt/mata-site/"Референсы" 2>/dev/null || true
cd /opt/mata/backend
umask 077

cat > .env <<ENVEOF
DJANGO_DEBUG=0
DJANGO_ALLOWED_HOSTS=api.mata-club.ru
DJANGO_CORS_ORIGINS=https://mata-club.ru,https://www.mata-club.ru,https://mata-media.storage.yandexcloud.net
POSTGRES_DB=mata
POSTGRES_USER=mata
POSTGRES_HOST=db
POSTGRES_PORT=5432
REDIS_URL=redis://redis:6379/0
DJANGO_MEDIA_ROOT=/srv/media
DJANGO_STATIC_ROOT=/app/staticfiles
SITE_PREVIEW_URL=https://mata-club.ru
APP_PREVIEW_URL=https://mata-media.storage.yandexcloud.net/mata-app-preview/index.html
LEGAL_DOCS_DIR=/legal_docs
TLS_DOMAIN=api.mata-club.ru
TLS_EMAIL=admin@mata-club.ru
TLS_EXTRA_SAN=mata-club.ru,www.mata-club.ru,158-160-12-117.nip.io
ENVEOF

# Секреты из Yandex Lockbox через сервисный аккаунт ВМ. Ретрай на случай «прогрева» SA.
LB_SECRET_ID="e6q1ias432ne7vtogghv"
for lb_try in $(seq 1 30); do
  IAM=$(curl -s -H "Metadata-Flavor: Google" "http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token" 2>/dev/null | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || true)
  if [ -n "$IAM" ]; then
    curl -s -H "Authorization: Bearer $IAM" "https://payload.lockbox.api.cloud.yandex.net/lockbox/v1/secrets/$LB_SECRET_ID/payload" 2>/dev/null \
      | python3 -c "import sys,json,shlex;[print(e['key']+'='+shlex.quote(e.get('textValue',''))) for e in json.load(sys.stdin).get('entries',[])]" >> .env 2>/dev/null || true
  fi
  grep -q "^POSTGRES_PASSWORD=" .env && { echo "Lockbox: секреты получены (попытка $lb_try)"; break; }
  echo "Lockbox: токен/секреты ещё не готовы (попытка $lb_try/30) — жду 10с..."
  sleep 10
done
for k in POSTGRES_PASSWORD DJANGO_SECRET_KEY JWT_SECRET; do
  grep -q "^$k=" .env || { echo "FATAL: $k отсутствует (Lockbox не отдал) — abort"; exit 1; }
done

# Постоянный диск под БД (/dev/vdb) — форматируем ТОЛЬКО пустой; монтируем в /mnt/data.
DBDEV=/dev/vdb
mkdir -p /mnt/data
if [ -b "$DBDEV" ]; then
  blkid "$DBDEV" >/dev/null 2>&1 || mkfs.ext4 -F "$DBDEV"
  DBUUID=$(blkid -s UUID -o value "$DBDEV")
  grep -q "$DBUUID" /etc/fstab || echo "UUID=$DBUUID /mnt/data ext4 defaults,nofail 0 2" >> /etc/fstab
  mount -a
fi
mountpoint -q /mnt/data || { echo "FATAL: /mnt/data not mounted — abort"; exit 1; }
mkdir -p /mnt/data/pgdata

cp nginx/mata.conf.example nginx/mata.conf
sed -i 's/api\.mata-store\.ru/api.mata-club.ru/g' nginx/mata.conf
docker compose -f docker-compose.prod.yml --env-file .env up -d --build db redis web worker beat
sleep 15
./deploy/smoke.sh || true
docker compose -f docker-compose.prod.yml --env-file .env exec -T web python manage.py seed_catalog || true
docker compose -f docker-compose.prod.yml --env-file .env exec -T web python manage.py createsuperuser --noinput 2>/dev/null || true
docker compose -f docker-compose.prod.yml --env-file .env exec -T web python manage.py publish_legal || true
echo "MATA deploy done" > /opt/mata-deploy.done
echo "=== TLS issue (inline) ==="
./deploy/tls.sh issue 2>&1 || echo "=== TLS issue FAILED (см. вывод выше) ==="
./deploy/backup.sh >> /var/log/mata-backup.log 2>&1 || true
echo "=== ГОТОВО: прод развёрнут (проверь https://api.mata-club.ru/v1/health) ==="
