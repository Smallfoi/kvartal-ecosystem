# Деплой / прод-конфиг экосистемы STAW

Чеклист перехода dev → прод. **В dev ничего настраивать не нужно** — везде заданы
рабочие dev-значения по умолчанию (backend `127.0.0.1:8000`, CORS открыт). Прод
включается переменными окружения (backend) и флагами сборки (приложения, сайт) —
код менять не нужно (кроме одного домена в сайте, см. ниже).

Единственное, что нужно завести при деплое, — **домен(ы)**:
- API, напр. `https://api.staw.ru` (база API = `https://api.staw.ru/v1`);
- сайт, напр. `https://staw.ru`.

---

## 1. Backend (Django)

**Готовый прод-стек** — `backend/docker-compose.prod.yml` (Django+gunicorn + PostGIS + nginx+TLS).
Шаблоны: `backend/.env.prod.example`, `backend/nginx/staw.conf.example`. Запуск:
```
cd backend && cp .env.prod.example .env   # заполнить секреты!
cp nginx/staw.conf.example nginx/staw.conf # подставить домен; certs/ — TLS
docker compose -f docker-compose.prod.yml --env-file .env up -d --build
```
web сам делает migrate → collectstatic → gunicorn (3 воркера); nginx форсит HTTPS, раздаёт /media, /static.
**Обязательно:** бэкапы БД (авто `pg_dump` + проверка восстановления — баллы = деньги!); внешний пинг `/v1/health`+алерты; Redis для общего rate-limit/кэша на нескольких воркерах (D-07); сменить дефолтный пароль/логин админки + ограничить `/admin/` по IP.

Задать переменные окружения (см. `backend/.env.prod.example`):

| Переменная | Прод-значение | Зачем |
|---|---|---|
| `DJANGO_DEBUG` | `0` | выключить отладку |
| `DJANGO_SECRET_KEY` | длинный случайный секрет | подпись Django |
| `JWT_SECRET` | ДРУГОЙ длинный случайный секрет | подпись токенов (иначе любой подделает токен!) |
| `DJANGO_ALLOWED_HOSTS` | `api.staw.ru` | какие хосты принимаем |
| `DJANGO_CORS_ORIGINS` | `https://staw.ru,https://www.staw.ru` | каким источникам сайта можно ходить в API (со схемой) |
| `POSTGRES_*` | прод-БД + сильный пароль | подключение к БД |

- ⚠️ **Fail-fast:** при `DJANGO_DEBUG=0` приложение НЕ стартует, если `JWT_SECRET`/`DJANGO_SECRET_KEY`/пароль БД дефолтные или `ALLOWED_HOSTS=*` (`common/prodcheck.py`) — защита от запуска с публичным dev-секретом.
- Секреты сгенерировать: `python -c "import secrets; print(secrets.token_urlsafe(64))"` (×2).
- `SEED_DEMO_POINTS` НЕ задавать — демо-баллы новичкам выключены (реальный лидерборд).
- Пока `DJANGO_CORS_ORIGINS` пуста → CORS открыт всем (dev). Как задана → только эти источники; они же идут в `CSRF_TRUSTED_ORIGINS` (для Django-admin).
- `SECURE_PROXY_SSL_HEADER` уже учитывает `X-Forwarded-Proto` от прокси (nginx-шаблон его шлёт).
- Миграции + `collectstatic` прод-compose делает сам; засеять каталог: `python manage.py seed_catalog`.

## 2. Приложения (Flutter) — Квартал и SportStore

База API задаётся при сборке через `--dart-define` (дефолт — dev `127.0.0.1:8000/v1`):

```bash
# SportStore
flutter build apk --release --target-platform android-arm64 \
  --dart-define=SPORT_STORE_API_BASE_URL=https://api.staw.ru/v1

# Квартал
flutter build apk --release --target-platform android-arm64 \
  --dart-define=KVARTAL_API_BASE_URL=https://api.staw.ru/v1
# (опц.) источник полигонов кварталов, если поднят отдельный zones-сервис:
#   --dart-define=KVARTAL_ZONES_URL=https://.../api/zones
```

На HTTPS не нужен cleartext — но `usesCleartextTraffic`/`INTERNET` в манифестах оставлены
(не мешают прод; нужны для dev по HTTP). Связь телефон↔dev-бек по USB: `adb reverse tcp:8000 tcp:8000`.

## 3. Сайт STAW

Раздавать по HTTPS. База API в `САЙТ STAW/ecosystem.js`:
- на `localhost`/`127.0.0.1` сам берёт dev (`127.0.0.1:8000/v1`);
- на проде берёт `PROD_API` — **заменить `https://api.staw.ru/v1` на реальный домен**
  (или задать `window.STAW_API_BASE = "https://..."` в `<head>` до подключения `ecosystem.js`).

## 4. После

- Проверить `GET https://api.staw.ru/v1/health` → `{"status":"ok"}`.
- Залогиниться на сайте/в приложениях, убедиться, что баллы общие.
- Секреты (SECRET_KEY, пароль БД) — только в окружении прод-сервера, НЕ в репозитории (он публичный).
