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


## 2026-06-17 — Claude — фон-добивка: wake-lock + разрешение на батарею + тип FGS
**Контекст:** владелец дал «Всегда» (ACCESS_BACKGROUND_LOCATION granted=true), но трек при выключенном экране всё равно не писался, а кнопка «отключить экономию батареи» не срабатывала.
**Причины (подтверждено adb):**
- В манифесте НЕ было `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` → `Permission.ignoreBatteryOptimizations.request()` — пустышка (кнопка «не нажималась»).
- В манифесте НЕ было `WAKE_LOCK`, и нативный сервис не держал wake-lock → CPU засыпал с выключенным экраном → GPS переставал писать.
- На Android 14+ `startForeground` без явного типа может отклоняться.
**Сделано:**
- Манифест: + `WAKE_LOCK`, + `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
- `KvartalLocationService`: partial wake-lock (acquire на старте, release на стопе/destroy, авто-таймаут 6 ч) + `startForeground(..., FOREGROUND_SERVICE_TYPE_LOCATION)` на API 29+.
- Проверено: оба разрешения в установленном APK granted=true.
**Дальше (живой тест владельца):** в листе нажать «Отключить экономию» (теперь покажет системный диалог) → разрешить; на Infinix вручную включить Автозапуск; пробежать с заблокированным экраном → трек должен догоняться.

## 2026-06-16 — Claude — тех-долг: убрал legacy FastAPI, CI-джоба на Django, .gitignore
**Сделано:**
- **Удалил FastAPI** (`backend/main.py`, `backend/requirements.txt`) — миграция на Django завершена и проверена (D-12). Ничто больше на них не ссылалось. README бэка обновил под Django+Docker.
- **CI:** джоба `Backend · FastAPI` → **`Backend · Django`** (working-dir `backend/django_api`, `pip install -r requirements.txt`, `python manage.py check`). Проверено в контейнере: «System check identified no issues».
- **Ruleset `protect-main`:** синхронно заменил required-проверку `Backend · FastAPI` → `Backend · Django` (иначе PR бы заблокировались на отсутствующей проверке).
- **.gitignore:** `**/devtools_options.yaml` (IDE-генерится, висел в untracked).
**Грабли:** при переименовании CI-джобы, которая в required status checks, ОБЯЗАТЕЛЬНО обновить контексты в ruleset через `gh api PATCH /rulesets/<id>` — иначе мерж блокируется навсегда.
**Дальше:** по D-13 — Store-магазин на бэке (каталог/заказы/списание баллов); либо доводка территорий/награды.

## 2026-06-16 — Claude — фоновая геолокация: онбординг + настойчивый запрос + обход «убийц фона»
**Контекст:** на устройстве проверил — `ACCESS_BACKGROUND_LOCATION granted=false`, appop `FINE: foreground`, не в whitelist батареи; Infinix агрессивно убивает фон. Поэтому трек вставал при блокировке экрана.
**Сделано (новая фича `features/permissions/`):**
- `location_access.dart` — обёртка permission_handler: уровень (denied/whenInUse/always), запрос whenInUse→always, батарея (`ignoreBatteryOptimizations`), бренд через канал; список агрессивных OEM (Transsion/Infinix/Tecno/Itel, Xiaomi, Huawei, Oppo/Vivo/Realme/OnePlus, Samsung…) + брендовые подсказки (dontkillmyapp).
- `location_access_provider.dart` — Riverpod-состояние (`fullyReady` = always + батарея).
- `location_setup_sheet.dart` — онбординг-лист с объяснением «зачем» и 3 шагами (доступ → «Разрешить всё время» → отключить экономию) + жёлтый блок-инструкция для агрессивных брендов; + `LocationWarningBanner` (постоянное предупреждение).
- MainActivity: метод канала `getManufacturer`.
- Экран Бег (`_IdleView` → ConsumerStatefulWidget): при первом запуске авто-показ листа (флаг `kvartal.loc_setup_shown.v1`), сверху постоянный баннер пока доступ не настроен.
**Проверено:** устройство = INFINIX (детектится как агрессивный OEM → показывается инструкция). analyze+test зелёные, собрал release, поставил.
**Дальше:** живой тест — выдать «Всегда» + снять экономию, пробежать с блокировкой экрана, убедиться что трек догоняется.

## 2026-06-16 — Claude — GPS: убрал дрожь маршрута 2–3 м (фильтр дистанции + точность)
**Сделано (по фидбэку владельца — трек рисовался с мелкими скачками 2–3 м на месте):**
- Корень: после удаления EMA осталась только грубая отбраковка (точность ≤50 м, шаг ≥2 м, `distanceFilter:0`) — GPS «дышит» на месте, каждая дрожащая точка попадала в трек.
- Лечение БЕЗ сглаживания (чтобы не срезать углы): фильтр дистанции на уровне ОС/провайдера + жёстче точность.
  - Dart (`run_provider`): `distanceFilter` 0→**5 м** (foreground+default `LocationSettings`), `_maxAcceptedAccuracyMeters` 50→**35**.
  - Нативный фон (`KvartalLocationService.kt`): `requestLocationUpdates(GPS,1000,**5f**,…)`, `MAX_ACCEPTED_ACCURACY` 50→**35f**.
- Реальные точки бега остаются «как есть» (точность хорошая на улице), дрожь на месте/мелких шагах отсекается на источнике.
**Состояние:** analyze зелёный, собрал release, поставил на устройство — нужен живой тест бега. Пороги (5 м/35 м) подкрутим по факту.
**Дальше (по плану владельца):** фоновая геолокация «всегда» с онбордингом/настойчивым запросом + предупреждение если не дали + обход «убийц фона» (Infinix/Transsion и др.).

## 2026-06-16 — Claude — D-14: гибридная модель территорий (живой слой 7д + вечный след)
**Сделано:** обсудили с владельцем модель территорий, зафиксировали **D-14 (гибрид)**.
- **Живой слой:** окно распада 72ч → **7 дней** (`HOLD_HOURS=168`); перехват бегом — всегда (как было).
- **Вечный личный след:** новая таблица `footprints` (миграция 0002, owner_id PK, MultiPolygon, GIST). При каждом
  захвате union в footprints (растёт, не уменьшается). `GET /v1/footprint` → `{areaM2, geojson}`.
- **Клиент:** `footprintAreaProvider` + карточка профиля «Личная территория · исследовано навсегда: N км²» (под статами);
  pull-to-refresh профиля обновляет и след.
**Проверено вживую :8000:** capture → live areaM2 + holdHoursLeft=168; footprint растёт (0 → 3499 м² после захвата). analyze+test зелёные.
**Грабли:** Docker DNS-хиккап — web не резолвил `db` после нескольких рестартов; лечится `docker compose up -d --force-recreate web`.
**Дальше:** опц. защита 24ч после захвата; визуальная heatmap следа на мини-карте профиля; подкрутить окна по живому тесту.

## 2026-06-16 — Claude — красота: отступы профиля, градиент Рейтинг/Бег, клуб = км (не баллы)
**Сделано (по фидбэку владельца):**
- **Профиль/Достижения:** компактные бейджи (childAspectRatio 0.9→1.02, иконка 32→28, паддинги ровные) — убрал «непонятные отступы» от высоких пустых плиток; выровнял ритм заголовок→контент = 10 (как в клубе).
- **Фоновый градиент** (синий сверху → чёрный) добавлен на **Рейтинг** и **Бег** (idle) — теперь единообразно с профилем/клубом.
- **Клуб = километры, не баллы (D-11/решение владельца):** активность клуба и вклад участников считаются по КМ (пробег растёт, не тратится), личные баллы кошелька в клубе больше НЕ показываем.
  - Бэк (clubs/views): `_km(uid)` = runnerRun/10; в `_summary` `totalKm` (вместо totalPoints), у участников `km` (вместо points), discovery-список сортируется по totalKm.
  - Клиент: `Club.totalKm`, `ClubMember.km`; шапка «Активность» = км (иконка маршрута), плитки участников и список клубов показывают км.
**Проверено вживую :8000:** /clubs/me → клуб «Тестовый» totalKm=35.8, участник km=35.8, points отсутствуют. analyze+test зелёные, пересобрал и поставил на устройство.

## 2026-06-16 — Claude — UX: навигация Настройки/Редактировать профиль + pull-to-refresh профиля
**Сделано (по фидбэку владельца):**
- **Навигация:** «Редактировать профиль» и «Настройки» переведены на маршруты внутри ShellRoute (`/profile/edit`, `/profile/settings`, открываются `context.push`) — раньше `Navigator.push` поверх таб-бара «залипал», тапы по вкладкам не переключали. Теперь таб-бар переключает; сохранение профиля закрывается `context.pop()`.
- **Pull-to-refresh профиля:** обернул `CustomScrollView` в `RefreshIndicator` (`AlwaysScrollableScrollPhysics`). Потянул вниз → `loyalty.refresh()` (баллы) + `auth.restoreSession()` (/auth/me) + `completedRuns.load()`. Кейс: потратил баллы в Store, вернулся в Квартал — теперь баллы можно обновить свайпом, не переключая экраны. Обновление между переходами экранов осталось (это в дополнение).
**Проверено:** analyze+test зелёные; пересобрал release, поставил на устройство.

## 2026-06-16 — Claude — UX-правки (по фидбэку владельца): навигация истории баллов + QR-приглашение
**Сделано:**
- **Баг навигации:** экран «История баллов» открывался через `Navigator.push` поверх таб-бара (внутр. навигатор шелла) → таб-бар оставался, но тапы по вкладкам не переключали. Сделал маршрут `/profile/points` внутри ShellRoute, карточка баллов открывает его `context.push` → теперь таб-бар переключает экраны корректно.
- **QR-приглашение в клуб:** убрал карточку «Код клуба» (не нужна — есть QR). Осталось QR + «Ссылка приглашения»: саму ссылку не показываем, только действие «копировать» (вся карточка тапается + кнопка). По просьбе владельца.
**Проверено:** analyze+test зелёные; пересобрал release и поставил на устройство.
**Прим.:** такой же баг (Navigator.push поверх таб-бара) есть у Settings/EditProfile — владелец про них не просил, не трогал.

## 2026-06-16 — Claude — вкладка «Районы» = контроль территорий + установка на устройство
**Сделано:**
- Пересобрал Квартал (release, arm64) и поставил на устройство Infinix X6873 (Android 15). `adb reverse tcp:8000`, вход сохранён. Проверено по логам Django: `auth/me 200`, `territories?bbox 200` — карта грузит территории с бэка вживую.
- **Вкладка «Районы» ожила** (была заглушка): теперь это **контроль территорий** — клубы по суммарной площади удерживаемых территорий (только активные <72ч).
  - Бэк: `GET /v1/leaderboard/districts` — SUM(ST_Area(geom::geography)) GROUP BY club_id из таблицы territories, имена/лого из Club, отметка isMine + myRank.
  - Клиент: `LeaderDistrictClub` + `leaderboardDistrictsProvider`; `_DistrictsTab` переписан на реальный список (стиль как у вкладки «Клубы», площадь м²/га/км², число территорий, прогресс-бар). Дизайн не трогал.
**Проверено вживую :8000:** districts → клуб «Тестовый» #1, area=13721 м², pieces=1, myRank=1. analyze+test зелёные.
**Прим.:** административных границ районов Якутска нет — поэтому «Районы» = городской контроль территорий клубами (city-wide). Разбивка по реальным районам — позже, когда будут полигоны границ.
**Дальше:** UI-бейдж «защищено Nч»; награды чемпионам недели/месяца; затем Store-магазин на бэке (D-13).

## 2026-06-16 — Claude — территории: 72ч-удержание + античит (D-09, сервер) + live-проверка
**Сделано (сервер, `territories/views.py`):**
- **72ч-удержание:** территория живёт 72ч от последнего захвата; новый забег обновляет `captured_at` и продлевает hold; протухшие удаляются лениво при capture (`DELETE ... captured_at <= now()-make_interval(hours=>72)`), а в list отдаются только свежие. В ответах появился `holdHoursLeft` (для UI «защищено ещё Nч»).
- **Античит:** мин. площадь 100 м² (дрожь GPS) → 400; макс. 2 км² за забег (спуфинг/телепорт) → 400; скорость >11.2 м/с (~40 км/ч) при наличии distance/elapsed → 400; кулдаун 30 с между захватами → 429.
**Сделано (клиент):** `territory_provider.capture(route, distanceMeters, elapsedSeconds)` шлёт дистанцию/время для античита; `run_screen` передаёт `run.distanceMeters`/`run.elapsed`; `ServerTerritory.holdHoursLeft` парсится.
**Проверено вживую на :8000** (Docker поднял сам, токен через `/auth/phone/verify` код 1234, номер пользователя): мало→400, скорость→400, много→400, валид→200 (hold=72), повтор→429 (кулдаун), list→rel=mine + holdHoursLeft=72.0. Клиент: analyze+test зелёные.
**Дальше:** на устройстве (adb reverse tcp:8000) пробежать петлю; UI-бейдж «защищено Nч»; затем оживить «Районы» в рейтинге (территории по клубам/районам).

## 2026-06-16 — Claude — клиент территорий в Квартале (D-09, клиентская часть)
**Сделано:**
- Привёл общий tree в порядок: GPS-фикс Codex (PR #26) и привязка SportStore к Django-аккаунту (PR #27, работа Codex) влиты в main; все CI зелёные.
- Новый `kvartal-app/lib/features/territory/data/territory_provider.dart` (Riverpod, паттерн как у club_provider):
  - `loadBbox(...)` → `GET /v1/territories?bbox=minLng,minLat,maxLng,maxLat` с Bearer-токеном, парсит GeoJSON (Polygon/MultiPolygon → внешние кольца LatLng), отношение mine/club/enemy с сервера.
  - `capture(route)` → `POST /v1/territories/capture {points:[[lat,lng],...]}`, сразу мёржит вернувшуюся свою территорию в стейт (показ без ожидания bbox).
- `map_screen.dart`: PolygonLayer реальных серверных территорий (mine=hexOwned / club=success / enemy=hexEnemy, та же палитра, дизайн не трогал); загрузка по видимой области с дебаунсом 600мс (init + onMapEvent move/zoom end).
- `run_screen.dart`: при подтверждении «Захватить» маршрут уходит на сервер (`territoryProvider.capture`), карта обновляется реактивно (она `watch`-ит territoryProvider). Локальный демо-захват оставлен (офлайн-фолбэк).
**Пробовали — не вышло:** `notifier.state = ...` из `ref.listen` — protected-варнинг; сделал публичный `reset()`.
**Проверено:** `flutter analyze` (No issues) + `flutter test` (зелено). Живой round-trip против :8000 НЕ гонял в этот раз — Docker в момент работы был выключен; контракт совпадает с ранее проверенным на сервере (порядок lat/lng в points, bbox minLng,minLat,maxLng,maxLat, форма ответа).
**Состояние:** территории работают сквозно client↔Django: захват по замкнутой петле шлётся на PostGIS, карта рисует mine/club/enemy по bbox. Дизайн не трогал.
**Дальше:** проверить на устройстве (adb reverse tcp:8000 + Docker up); затем серверный 72ч-холд + античит (скорость/площадь/cooldown); затем оживить вкладку «Районы» в рейтинге.

## 2026-06-15 — Claude — D-13 + бэкенд территорий на PostGIS (D-09, серверная часть)
**Сделано:** зафиксировал **D-13** (экосистема: единый бэк, контракт-first, подключаем поверхности постепенно;
порядок: территории → Store-магазин → сайт). Начал **территории на PostGIS** (raw SQL, без GeoDjango/GDAL):
- app `territories` + миграция (RunSQL: postgis + таблица `territories` owner_id UNIQUE, geom MultiPolygon(4326), GIST-индекс).
- `POST /v1/territories/capture {points:[[lat,lng],...]}` — строит полигон из маршрута, сглаживает
  (ST_SimplifyPreserveTopology ~5м + ST_MakeValid), своя территория растёт через ST_Union (расширение),
  у чужих вычитается пересечение ST_Difference (перехват). Один владелец = одна мульти-территория.
- `GET /v1/territories?bbox=minLng,minLat,maxLng,maxLat` — территории в области, отметка mine/club/enemy, упрощение по зуму.
**Проверено на :8000:** capture→5601 м², bbox→mine, повторный союзный захват→11201 м² (union растёт). Перехват — логика на месте.
**Состояние:** серверная часть территорий MVP готова. Клиент Квартала ещё НЕ шлёт/не рисует серверные территории.
**Дальше (клиент):** при замыкании петли POST /territories/capture; на карте грузить /territories?bbox и рисовать
полупрозрачно mine/club/enemy; потом 72ч-удержание + античит на сервере; затем Районы-рейтинг оживёт.

## 2026-06-15 — Claude — ПЕРЕХОД НА DJANGO ЗАВЕРШЁН (clubs+leaderboard, данные, :8000)
**Сделано:** (1) перенёс clubs + leaderboard на Django (PR #22) — все эндпоинты теперь на Django/DRF, контракт как у FastAPI.
(2) Миграция данных: `core/management/commands/import_sqlite.py` — `docker compose cp ecosystem.db web:/tmp/` →
`flush` (чистка тестовых) → `import_sqlite`. Перенесено 9 юзеров / 50 транзакций / 1 клуб / 1 участник.
(3) Переключение: docker-compose web порт 8001→**8000**, FastAPI остановлен; приложения через `adb reverse tcp:8000`
теперь ходят в Django без пересборки и БЕЗ перелогина (JWT совместим).
**Проверено на устройстве:** Квартал → профиль «Михаил Татаринов», телефон/город, баллы 678/Золото, карта — всё из Django.
**Состояние:** ✅ бэкенд = Django + PostgreSQL/PostGIS (Docker, :8000). FastAPI (`backend/main.py`) остановлен, оставлен как legacy.
Запуск: `cd backend && docker compose up -d` (после перезагрузки сначала запустить Docker Desktop).
**Дальше:** территории на PostGIS (D-09, «сердце»); потом убрать legacy FastAPI + обновить CI-джобу на Django; синк пробежек.

## 2026-06-15 — Claude — Django-стек ЖИВ + перенос ядра (auth/profile/loyalty)
**Сделано:** владелец поднял WSL2 + Docker. Запустил стек: `cd backend && docker compose up --build -d` →
db (postgis/postgis:16-3.4, PostGIS 3.4.3 ✅) + web (Django :8001). `migrate` ок, `GET http://localhost:8001/v1/health` = ok, db:true.
Перенёс на Django/DRF ЯДРО с тем же контрактом: `accounts` (Account) + `loyalty` (LoyaltyTransaction) + `common/security.py`
(JWT HS256 + pbkdf2-пароли — БАЙТ-В-БАЙТ как FastAPI, тот же секрет → токены совместимы). Эндпоинты:
`POST /v1/auth/register|login|phone/verify`, `GET /v1/auth/me`, `PATCH /v1/profile`, `GET /v1/loyalty/account`,
`POST /v1/loyalty/transactions` (идемпотентность по runId+source), seed_runner_points при создании юзера.
**Проверено на :8001:** phone/verify(8 914 827 8470) → provider phone, баланс 430/silver/5 txns; register +430; profile PATCH; me.
**Состояние:** Django отдаёт ядро идентично FastAPI на Postgres. FastAPI (:8000) НЕ тронут — приложения работают.
**Запуск стека (важно):** `cd backend && docker compose up -d`; миграции `docker compose exec web python manage.py migrate`.
**Дальше:** перенести clubs + leaderboard на Django; миграция данных SQLite→Postgres; переключить baseUrl приложений на :8001; затем отключить FastAPI; затем территории (PostGIS, D-09).

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
