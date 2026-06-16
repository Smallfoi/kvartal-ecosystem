# STAW Ecosystem Backend (walking skeleton)

Общий backend экосистемы (Квартал + Store + Сайт). Реализует часть контракта
`../ECOSYSTEM_API.md`: **Auth (SSO/JWT) + Loyalty (единый баланс баллов)**.

Это «шагающий скелет»: минимальный реальный срез, доказывающий единый аккаунт и
единые баллы end-to-end. Остальные сервисы (Catalog/Order/Shoes) добавляются
инкрементально.

## Стек
- **Django 5 + DRF** (каталог приложения — `django_api/`). Контракт API совместим с прежним
  (auth/profile/loyalty/clubs/leaderboard), JWT/хэш паролей — байт-в-байт как раньше.
- БД — **PostgreSQL + PostGIS** (территории на гео-запросах), через Docker.
- Прежний прототип на FastAPI (`main.py`) удалён после завершения миграции (см. D-12 в `../docs/DECISIONS.md`).
  Историческая SQLite-база `ecosystem.db` использовалась только для разовой миграции данных.

## Запуск (Docker)
```bash
cd backend
docker compose up -d        # db (postgis) + web (Django) на :8000
```
После перезагрузки сначала запустить Docker Desktop. Проверка: http://localhost:8000/v1/health

## Эндпоинты
| Метод | Путь | Назначение |
|---|---|---|
| POST | /v1/auth/register | регистрация → {token, user} (+демо-баллы «из Квартала») |
| POST | /v1/auth/login | вход → {token, user} |
| GET | /v1/auth/me | профиль (Bearer) |
| GET | /v1/loyalty/account | баланс + уровень + история (Bearer) |
| POST | /v1/loyalty/transactions | начисление/списание (Bearer) |
| GET | /v1/health | проверка |

## Подключение мобильного приложения (Store)
Телефон обращается к ПК по локальной сети. В `sport_store/lib/data/api/api_config.dart`:
- `baseUrl = 'http://<IP_ПК>:8000/v1'` (например `http://192.168.1.56:8000/v1`)
- включить API для Auth и Loyalty (per-service флаги)
- Android: разрешить cleartext HTTP для dev (debug manifest)


---

## Update 2026-06-09: phone auth and shared profile

The backend is now the source of truth for the ecosystem account profile.

New/updated endpoints:

| Method | Path | Purpose |
|---|---|---|
| POST | /v1/auth/phone/verify | Dev phone verification with code `1234`; returns JWT + user. One phone maps to one backend user_id. |
| GET | /v1/auth/me | Returns current user profile by Bearer JWT, including `city`. |
| PATCH | /v1/profile | Updates shared profile fields: `name`, `phone`, `email`, `city`, `avatarPath`. |

Dev mobile setup:

```powershell
cd D:\MyProjectsCLAUDE\backend
docker compose up -d
adb reverse tcp:8000 tcp:8000
```

Apps should treat backend as the source of truth. Local app storage is only a cache.

Current next task for SportStore: move profile editing from local-only `AuthProvider.updateProfile(...)` to backend `PATCH /v1/profile`, and refresh profile from `GET /v1/auth/me` when JWT exists.
