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
[ -n "$DOMAIN" ] || { echo "ОШИБКА: задай TLS_DOMAIN в .env (напр. api.staw.ru)"; exit 1; }
[ -n "$EMAIL" ]  || { echo "ОШИБКА: задай TLS_EMAIL в .env (куда слать письма об истечении)"; exit 1; }

COMPOSE="docker compose -f docker-compose.prod.yml --env-file .env"
LE_DIR="$PWD/nginx/letsencrypt"    # состояние certbot (ключи аккаунта, архив сертификатов)
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
    echo "Выпуск сертификата для $DOMAIN — nginx остановится на ~минуту…"
    # nginx не стартует без сертификата (ssl_certificate), поэтому первый выпуск —
    # standalone: certbot сам поднимает временный сервер на :80.
    $COMPOSE stop nginx 2>/dev/null || true
    docker run --rm -p 80:80 -v "$LE_DIR:/etc/letsencrypt" certbot/certbot \
      certonly --standalone --non-interactive --agree-tos -m "$EMAIL" -d "$DOMAIN"
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
