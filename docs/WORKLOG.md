# WORKLOG — журнал работы над экосистемой STAW

Единый журнал для **Claude + Codex**. Свежие записи сверху. После каждой смены —
добавить запись по шаблону. Глубокие детали по Квparталу: `kvartal-app/HISTORY.md`.

Шаблон записи:
```
## YYYY-MM-DD — <Claude|Codex> — заголовок
**Сделано:** …
**Пробовали — не вышло:** …   (чтобы второй не повторял)
**Решения:** …                (продублировать в DECISIONS.md, если архитектурное)
**Состояние:** что сейчас работает
**Дальше:** …
```

---


## 2026-06-15 — Claude — каркас Django + Postgres/PostGIS (Docker)
**Сделано:** `backend/django_api/` (Django-проект `config` + app `core` с `/v1/health`, Dockerfile, requirements,
settings под Postgres из env) и `backend/docker-compose.yml` (`db` postgis/postgis + `web` Django на хосте :8001).
FastAPI (:8000) остаётся рабочим во время перехода. Решение **D-12**.
**Решения:** D-12 — переезд на Django+PostGIS в Docker рядом с FastAPI; FastAPI держим до паритета, цель — Django-only.
**Пробовали — не вышло:** Docker Desktop поставлен (winget), но не стартует — **нет WSL2** (`wsl --install`, нужен админ+перезагрузка от владельца). `psycopg`/драйверы на хостовый Python 3.14 не ставим — Django живёт в контейнере.
**Состояние:** каркас собран (синтаксис ок), но НЕ запущен (ждёт WSL2+Docker). Приложения работают на FastAPI.
**Дальше:** владелец ставит WSL2 и запускает Docker → `cd backend && docker compose up` → migrate → `/v1/health` →
перенос эндпоинтов по модулям (auth→profile→loyalty→clubs→leaderboard) → данные → переключение приложений → территории (D-09).

## 2026-06-15 - Codex - Club invite MVP
**Done:** added Flutter club invite flow: owner can open an invite sheet with QR, invite link, and copyable club code; users without a club can paste a code/link and join or send a request through existing backend club join rules. Added `qr_flutter`.
**Decisions:** MVP invite code is the existing `club.id` and link format is `https://kvartal.app/club/<club_id>`; backend invite tokens/deep links/media sharing should be added later.
**State:** `flutter analyze` and `flutter test` are green.
**Next:** add backend invite-token endpoint, deep links/app links, and owner invite by phone/nickname after user search/notifications exist.

## 2026-06-15 — Claude — UI рейтинга (км, Неделя/Месяц)
**Сделано:** `leaderboard/data/leaderboard_provider.dart` (Dio + FutureProvider'ы users/clubs по периоду) и
переписан `leaderboard_screen.dart` на реальные данные (дизайн сохранён): переключатель **Неделя/Месяц**,
метрика **км**, подиум + «Ваше место», список; вкладка «Клубы» (твой клуб подсвечен); «Районы» — честная
заглушка до территорий (D-09). «Ты»→«Вы» (без скобок).
**Состояние:** проверено на устройстве — Личный (я #1, 26.2 км, «Вы»), Клубы («Тестовый» #1), Районы (заглушка).
Бэкенд — PR #16, решение D-11. Также сохранил незакоммиченную правку Codex (кнопка формы клуба, PR #17).
**Дальше:** награды за неделю/месяц (этап 2), синк пробежек (точные км/история), территории на сервере (D-09).

## 2026-06-15 - Codex - Club edit sheet UX fixes
**Done:** edit sheet now uses edit/save wording for existing clubs, has extra bottom gap above the app nav bar, and logo section is redesigned with preview, richer presets, and a disabled own-photo upload placeholder until media storage is added.
**State:** `flutter analyze`, `flutter test`, and `git diff --check` are green.
**Next:** implement real club logo upload via backend media storage/CDN and image picker.

## 2026-06-14 - Codex - Club owner admin UI and metrics polish
**Done:** added club edit flow for owner through existing PATCH `/v1/clubs/{id}`; owner now has mini admin card for name/city/description/logo/join policy. Replaced dry top stats with icon metric cards: activity, members, entry policy.
**Decisions:** club points in current UI are treated as club activity/ranking, not spendable wallet. Personal loyalty points remain user-owned and spendable in Store.
**State:** `flutter analyze`, `flutter test`, and `git diff --check` are green.
**Next:** install on phone and visually verify Club tab; later formalize personal vs club points in DECISIONS/API docs.

## 2026-06-14 - Codex - Club empty state layout fix
**Done:** moved create-club action from floating button into the top empty-state card; search is now a separate block; removed ellipsis usage from club screen and added scale-down text helper for one-line labels.
**State:** installed updated debug APK on Infinix X6873; `flutter analyze` is green.
**Next:** owner should visually check the Club tab on the phone and confirm text fit on the real screen.

## 2026-06-14 - Codex - Kvartal Clubs UI connected to backend
**Done:** added `kvartal-app/lib/features/club/data/club_provider.dart`; rewrote `ClubScreen` to use `/v1/clubs/me`, `/v1/clubs`, create club, search, join/request, leave, owner requests approve/reject, real members and backend points.
**Tried - failed:** `apply_patch` cannot write to real monorepo `D:\\MyProjectsCLAUDE` from the stale Codex cwd; used UTF-8 Python/PowerShell with escalated access.
**Decisions:** removed demo members/challenges/territories as real data. Challenges and club territories remain honest future cards until run-sync and server geometry D-09.
**State:** `flutter analyze` and `flutter test` in `kvartal-app` are green. Clubs: backend done, UI MVP partial.
**Next:** test club create/join on phone; then backend run-sync for real club kilometers and leaderboard.

## Текущее состояние экосистемы (снимок на 2026-06-14)
- **Backend (FastAPI + SQLite, dev):** общий аккаунт + общие баллы. Эндпоинты:
  `POST /v1/auth/register|login|phone/verify`, `GET /v1/auth/me`, `PATCH /v1/profile`,
  `GET /v1/loyalty/account`, `POST /v1/loyalty/transactions` (идемпотентен по `runId+source`), `GET /v1/health`.
  SSO по телефону (dev-код `1234`), один телефон → один `user_id`.
- **Квартал:** вход по телефону, профиль и баллы через общий бек; карточка «Баллы экосистемы»;
  автоначисление за пробежку (10 б/км) и захват территории (+50) с офлайн-очередью.
- **SportStore:** вход (email + телефон), профиль и баллы через тот же бек. Тот же аккаунт, что в Квартале.
- **Сайт STAW:** статика, к беку пока не подключён.
- **Инфраструктура:** монорепо `Smallfoi/kvartal-ecosystem` (GitHub, PUBLIC), CI (GitHub Actions),
  защита `main` (PR обязателен, CI обязателен, без прямого push).
- **Доказано на устройстве:** телефон `+79148278470` → один аккаунт `u_fbff802b3ddffc10`
  (Михаил Татаринов) виден в Квартале и Store; начисление баллов в одном приложении видно в другом.

---

## 2026-06-14 — Claude — карта модулей экосистемы (docs/MODULES.md)
**Сделано:** введён единый список модулей `docs/MODULES.md` (ядро / Квартал / Store / Сайт / инфраструктура)
со статусами (✅/🟡/🔴) и привязкой к приложениям+бэку. Ссылка добавлена в CLAUDE.md и AGENTS.md.
**Решения:** разбиваем экосистему на модули; при изменении модуля — обновлять его статус в MODULES.md.
**Состояние:** справочник готов. Статусы на сейчас: Auth/Profile/Loyalty/Map/Achievements ✅; Clubs бэк ✅ UI 🔴;
Run/Catalog/Cart/Notifications/Site 🟡; Territories/Leaderboard/Shoes/Admin/Insights 🔴.
**Дальше:** по плану — UI Клуба, синк пробежек, Рейтинг, территории на сервере.

## 2026-06-14 — Claude — бэкенд клубов (FastAPI)
**Сделано:** таблицы `clubs` / `club_members` (uniq `user_id` → один клуб на человека) / `club_join_requests`
+ эндпоинты: list/search, create, me, detail, patch, join, leave, requests, approve/reject. Политика
вступления `open`/`request` — выбор владельца. Агрегаты клуба — по баллам участников (км пока не на бэке).
**Решения:** D-10 (см. DECISIONS).
**Проверено:** python end-to-end — create → 409 (повтор/второй клуб) → list → join(request) → owner видит
заявки → approve → me(2 участника) → join 409 → leave → owner leave один = клуб удалён. Всё ок.
**Состояние:** бэкенд клубов готов; UI ещё нет. Профиль/карта/баллы — работают.
**Дальше:** Flutter — вкладка Клуб: discovery (создать/поиск/список) + my-club + create-форма + join;
по плану также синк пробежек на бэк (чтобы клубные км были реальными) и Рейтинг.

## 2026-06-14 — Claude — зафиксирована модель территорий (D-09)
**Сделано:** записан **D-09** — территория = полигон реального бегового маршрута (НЕ гексы),
полупрозрачная заливка с видимой картой + насыщенный контур, расширение касанием своей границы
(выход/вход в 2 точках → `ST_Union`), перехват чужого (`ST_Difference`), сглаживание/чистка GPS при
фиксации на сервере, упрощение по зуму, загрузка по видимой области, сервер — источник правды, PostGIS.
**Отклонено:** H3-гексы (ломают суть/вид «Квартала»); заготовленные блоки `zones.json` как единица владения.
**Состояние:** решение зафиксировано; код карты пока не менялся. В коде уже есть зерно — `CapturedArea` (полигон маршрута).
**Дальше:** реализация поэтапно вместе с переходом на PostGIS — перенести зоны в общий бек (убрать `localhost:3000`),
viewport-загрузка, заливка по реальному маршруту, серверные захват/union/difference, 72ч и античит на сервере.

## 2026-06-14 — Claude — единая система совместной работы
**Сделано:** созданы корневые `CLAUDE.md` + `AGENTS.md` (одни правила для обоих агентов) и
`docs/WORKLOG.md` / `DECISIONS.md` / `PITFALLS.md`. Зафиксированы незакоммиченные заметки Codex (Docker).
**Решения:** единый источник правды по работе = `docs/WORKLOG.md`; вести `DECISIONS.md` и `PITFALLS.md`.
**Состояние:** инфраструктура совместной работы готова.
**Дальше:** по очереди наращивать фичи на FastAPI; позже — Django (см. DECISIONS).

## 2026-06-13 — Codex — стратегия GitHub/Django + Docker
**Сделано:** хендофф `kvartal-app/CLAUDE_HANDOFF_GITHUB_DJANGO_2026-06-13.md` — переход на GitHub-флоу,
монорепо, постепенная миграция backend FastAPI → Django + DRF (контракты не ломать, FastAPI не удалять).
Добавлено решение про Docker (нужен позже: Django/PostgreSQL/PostGIS/Redis/Celery), не блокирует текущие шаги.
**Решения:** см. DECISIONS (Django-миграция, Docker).
**Состояние:** документ-стратегия; код не менялся.
**Дальше:** Phase 2 — бутстрап Django рядом с FastAPI (когда дойдём).

## 2026-06-13 — Claude — офлайн-очередь баллов + идемпотентность (PR #3)
**Сделано:** Квартал — начисления в очередь (SharedPreferences), досыл при `refresh()`;
backend — `POST /loyalty/transactions` идемпотентен по `(user_id, runId, source)`.
**Пробовали — не вышло:** наивный «best-effort» POST терял баллы при офлайне (на улице бека нет).
**Состояние:** баланс пользователя 520 (Золото, порог 500). Проверено: POST ×3 одним runId = +30 один раз.
**Дальше:** реальный тест прогулкой (нужно движение по GPS).

## 2026-06-13 — Claude — автоначисление баллов за пробежку (PR #2)
**Сделано:** `run_provider._saveCompletedRun` → начисление 10 б/км + 50 за территорию через `loyalty.award()`.
**Состояние:** на устройстве — без регрессий; полный путь требует реальной пробежки (GPS).

## 2026-06-13 — Claude — CI + защита main (PR #1) и монорепо
**Сделано:** `git init` в корне, первый коммит; `.github/workflows/ci.yml` (Flutter analyze/test ×2 + бэкенд);
репозиторий сделан PUBLIC; ruleset `protect-main` (PR + обязательные проверки, без прямого push).
**Пробовали — не вышло:** branch protection на ПРИВАТНОМ репо бесплатного плана = 403 (нужен Pro или public).
**Решения:** репозиторий публичный (см. DECISIONS); рабочий процесс = ветка + PR + зелёный CI.

## 2026-06-10..13 — Claude — общий аккаунт и баллы на устройстве
**Сделано:** профиль Store ↔ бек (`PATCH /profile`, `GET /auth/me`); Квартал подключён к беку
(вход/профиль/баллы); карточка баллов в Квартале; доказан общий аккаунт и общий баланс в обоих приложениях.

## ранее — walking skeleton backend (Auth + Loyalty)
**Сделано:** FastAPI + SQLite, JWT/пароли на stdlib; единый аккаунт + общий баланс баллов как первый
вертикальный срез экосистемы. Подробности — `kvartal-app/HISTORY.md` и `backend/`.
