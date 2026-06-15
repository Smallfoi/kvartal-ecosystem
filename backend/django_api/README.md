# django_api — бэкенд экосистемы STAW на Django (этап перехода)

Цель (D-06/D-07): постепенный переезд бэкенда с FastAPI на **Django + DRF + PostgreSQL/PostGIS**.
FastAPI (`backend/main.py`, порт 8000) пока работает и обслуживает приложения. Django поднимаем
**рядом** на порту 8001, переносим эндпоинты, проверяем, затем переключаем приложения и отключаем FastAPI.

## Запуск (нужен установленный и запущенный Docker Desktop)
```
cd backend
docker compose up --build
```
- Django: http://localhost:8001/v1/health
- Postgres+PostGIS: localhost:5432 (kvartal/kvartal/kvartal)

## Что уже есть
- Каркас Django-проекта `config` + приложение `core` с `/v1/health`.
- `docker-compose.yml`: `db` (postgis/postgis) + `web` (Django).
- Настройки БД/секретов — через переменные окружения.

## Дальше (по порядку)
1. Поднять стек в Docker, прогнать `migrate`, проверить `/v1/health`.
2. Перенести эндпоинты по модулям, сохраняя JSON-контракт FastAPI:
   accounts/auth → profile → loyalty → clubs → leaderboard.
3. Перенести данные SQLite → Postgres.
4. Переключить `baseUrl` приложений на Django, проверить на устройстве, отключить FastAPI.
5. Включить PostGIS (GeoDjango/raw SQL) и реализовать **территории (D-09)**.

> PostGIS-расширение есть в образе `postgis/postgis`. Для GeoDjango в web-контейнер позже
> добавим GDAL/GEOS (apt: `gdal-bin libgdal-dev`) либо считаем геометрию через raw SQL (psycopg).
