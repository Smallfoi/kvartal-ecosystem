#!/usr/bin/env bash
# TLS-сертификаты Let's Encrypt для прод-nginx STAW (бесплатно, автообновление).
# Запускать НА СЕРВЕРЕ из каталога backend/ (домен уже должен указывать A-записью на IP):
#   ./deploy/tls.sh issue   — первый выпуск (nginx останавливается на ~минуту, порт 80 нужен certbot)
#   ./deploy/tls.sh renew   — обновление БЕЗ простоя (ACME-проверка через nginx), в cron раз в неделю
set -euo pipefail

cd "$(dirname "$0")/.."  # → backend/
[ -f .env ] || { echo "Нет .env (см. .env.prod.example)"; exit 1; }
set -a; . ./.env; set +a

DOMAIN="${TLS_DOMAIN:-}"
EMAIL="${TLS_EMAIL:-}"
[ -n "$DOMAIN" ] || { echo "ОШИБКА: задай TLS_DOMAIN в .env (напр. api.mata-club.ru)"; exit 1; }
[ -n "$EMAIL" ]  || { echo "ОШИБКА: задай TLS_EMAIL в .env (куда слать письма об истечении)"; exit 1; }

COMPOSE="docker compose -f docker-compose.prod.yml --env-file .env"
# Состояние certbot — на ПОСТОЯННОМ диске (если смонтирован), чтобы сертификат пережил
# пересоздание ВМ и НЕ перевыпускался каждый раз (иначе упираемся в лимиты ACME/LE).
if mountpoint -q /mnt/data 2>/dev/null; then
  LE_DIR="/mnt/data/letsencrypt"
else
  LE_DIR="$PWD/nginx/letsencrypt"
fi
WEBROOT="$PWD/nginx/certbot-www"   # сюда certbot кладёт файл ACME-проверки, его отдаёт nginx
CERTS="$PWD/nginx/certs"           # отсюда nginx читает fullchain.pem/privkey.pem
mkdir -p "$LE_DIR" "$WEBROOT" "$CERTS"

# Разложить свежий сертификат туда, где его ждёт nginx (в live/ лежат симлинки → cp -L).
install_certs() {
  local live="$LE_DIR/live/$DOMAIN"
  [ -f "$live/fullchain.pem" ] || { echo "ОШИБКА: сертификат не найден в $live"; exit 1; }
  cp -L "$live/fullchain.pem" "$CERTS/fullchain.pem"
  cp -L "$live/privkey.pem"   "$CERTS/privkey.pem"
  chmod 600 "$CERTS/privkey.pem"
  echo "Сертификаты разложены в nginx/certs/."
}

case "${1:-}" in
  issue)
    # Сертификат уже есть (на постоянном диске от прошлого выпуска) — не перевыпускаем
    # (бережём лимиты ACME), просто раскладываем и поднимаем nginx.
    if [ -f "$LE_DIR/live/$DOMAIN/fullchain.pem" ]; then
      echo "Сертификат уже есть в $LE_DIR — переиспользую без перевыпуска."
      install_certs
      $COMPOSE up -d nginx
      exit 0
    fi
    echo "Выпуск сертификата для $DOMAIN — nginx остановится на ~минуту…"
    # nginx не стартует без сертификата (ssl_certificate), поэтому первый выпуск —
    # standalone: certbot сам поднимает временный сервер на :80.
    $COMPOSE stop nginx 2>/dev/null || true
    ACME_LE="${ACME_SERVER:-https://acme-v02.api.letsencrypt.org/directory}"   # LE (по умолчанию)
    ACME_ZS="https://acme.zerossl.com/v2/DV90"                                  # запасной CA (без лимитов LE)
    # --dns: форсируем публичные резолверы. EXTRA: доп. SAN (<IP>.nip.io) делает набор доменов
    # уникальным → обходит лимит LE «5 одинаковых сертов/неделю» (возник из-за пересозданий).
    EXTRA=""; [ -n "${TLS_EXTRA_SAN:-}" ] && EXTRA="-d ${TLS_EXTRA_SAN}"
    issue_le() {
      docker run --rm -p 80:80 --dns 8.8.8.8 --dns 1.1.1.1 -v "$LE_DIR:/etc/letsencrypt" certbot/certbot \
        certonly --standalone --non-interactive --agree-tos -m "$EMAIL" --server "$ACME_LE" -d "$DOMAIN" $EXTRA
    }
    issue_zerossl() {
      docker run --rm -p 80:80 --dns 8.8.8.8 --dns 1.1.1.1 -v "$LE_DIR:/etc/letsencrypt" certbot/certbot \
        certonly --standalone --non-interactive --agree-tos -m "$EMAIL" --server "$ACME_ZS" \
        --eab-kid "${ZEROSSL_EAB_KID:-}" --eab-hmac-key "${ZEROSSL_EAB_HMAC:-}" -d "$DOMAIN"
    }
    issue_le || { echo "LE не выдал сертификат (лимит?) — пробую ZeroSSL…"; issue_zerossl; }
    install_certs
    $COMPOSE up -d nginx
    echo "Готово. Проверь: curl -I https://$DOMAIN/v1/health"
    ;;
  renew)
    # Обновление — webroot: nginx продолжает работать, отдавая /.well-known/acme-challenge/.
    # Если до истечения больше 30 дней, certbot ничего не делает и выходит с кодом 0.
    docker run --rm -v "$LE_DIR:/etc/letsencrypt" -v "$WEBROOT:/var/www/certbot" \
      certbot/certbot renew --webroot -w /var/www/certbot --non-interactive
    install_certs
    $COMPOSE exec -T nginx nginx -s reload
    echo "Обновление завершено, nginx перечитал конфигурацию."
    ;;
  *)
    echo "Использование: $0 {issue|renew}"
    exit 1
    ;;
esac
