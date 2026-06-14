# История разработки КВАРТАЛ

## Сессия 1 — 2026-05-23
**Статус:** PRD готов

### Сделано
- Составлен полный PRD v1.1 (`PRD.md`)
- Исследован рынок (Strava, Nike Run Club, Ingress, Turf War и др.)
- Определены незакрытые ниши: русскоязычное приложение + Якутск-специфика + бег+территории+социал
- Выбран технический стек: Flutter + Go + PostgreSQL/PostGIS
- Подтверждены решения по открытым вопросам:
  - Flutter (не React Native)
  - Apple Health / Google Fit — да
  - Авторизация: SMS + VK + Google + Apple Sign In
  - Garmin/Apple Watch — через Health (MVP), прямой BLE (v2.0)

### Ключевые решения
- Монетизация: Freemium, PRO за 299 руб/мес или 1999 руб/год
- Гексагоны: H3 уровня 9 (~174м), удержание 72ч, 1–5 звёзд силы
- Клубный захват: 3+ члена клуба → территория становится клубной
- Инфраструктура: Яндекс.Облако (Владивосток/Новосибирск)

---

## Сессия 2 — 2026-05-27
**Статус:** Flutter-проект инициализирован, базовая навигация готова

### Сделано
- Создан Flutter-проект `kvartal_app` (Flutter 3.32.1, Dart 3.8.1)
- Настроены зависимости в `pubspec.yaml`:
  - go_router ^14.6.3 (навигация)
  - flutter_riverpod ^2.6.1 + riverpod_annotation (state)
  - flutter_map ^7.0.2 + latlong2 (карты)
  - geolocator ^13.0.2 + permission_handler (GPS)
  - fl_chart ^0.70.2 (графики)
  - flutter_animate ^4.5.2 (анимации)
  - dio ^5.8.0+1 (HTTP)
  - shared_preferences + flutter_secure_storage (хранение)
  - intl, equatable (утилиты)
- Создана структура папок (feature-first):
  ```
  lib/core/ — theme, router, constants
  lib/features/ — map, run, leaderboard, club, profile, auth
  lib/shared/ — widgets
  assets/ — images, icons
  ```
- Реализована тёмная тема (`AppColors`, `AppTheme.dark`):
  - Electric blue `#0A84FF` как акцентный цвет
  - Фон `#0D0D0D`, поверхности `#1A1A1A` / `#242424`
  - Полная кастомная типографика
- Настроена навигация (`go_router`, `ShellRoute`):
  - 5 табов: Карта / Бег / Рейтинг / Клуб / Профиль
  - Кастомный NavBar с pill-кнопкой для "Бег"
- Созданы UI-скелеты всех 5 экранов:
  - **MapScreen** — заглушка карты + погода (-24°C, x1.4 бонус) + статистика зон
  - **RunScreen** — Quick Start карточка с градиентом + цель недели + история пробежек
  - **LeaderboardScreen** — 3 таба (личный/клубы/районы) + podium top-3
  - **ClubScreen** — карточка клуба + участники + клубные вызовы
  - **ProfileScreen** — SliverAppBar + статистика + бейджи + тепловая карта активности
- Создан `CLAUDE.md` с документацией проекта
- Создан `HISTORY.md` (этот файл)

---

## Сессия 3 — 2026-05-27 (продолжение)
**Статус:** Карта OSM + GPS-трекинг реализованы, `flutter analyze` — 0 ошибок

### Сделано
- Добавлены GPS-разрешения:
  - Android: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`
  - iOS: `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`
- Создан `lib/features/map/data/location_provider.dart`:
  - `locationPermissionProvider` — запрашивает разрешение
  - `currentPositionProvider` — разовое получение позиции
  - `positionStreamProvider` — поток координат (distanceFilter: 5м)
  - extension `PositionToLatLng` — конвертер Position → LatLng
- Создан `lib/features/run/data/run_provider.dart`:
  - `RunState` (route, elapsed, distanceMeters, status)
  - `RunNotifier` (start/pause/resume/stop) — StateNotifier
  - Античит: игнорирует точки при скорости > 40 км/ч
  - Таймер через `Timer.periodic` + GPS поток через geolocator
- Переписан `MapScreen` с реальной картой:
  - `FlutterMap` + CartoDB Dark Matter тайлы
  - `PolylineLayer` — маршрут активной тренировки
  - `MarkerLayer` — маркер пользователя (синий/зелёный при беге)
  - Кнопка "вернуться к позиции" при ручном перемещении карты
  - Нижняя панель меняется: статика зон ↔ живые метрики тренировки
- Переписан `RunScreen`:
  - Idle-вид: старт-карточка + цель недели + история
  - Active-вид: большой счётчик дистанции (80px), темп, время, управление
  - Диалог завершения с итогами
  - Статус-бейдж «ЗАПИСЬ» / «ПАУЗА»
- PRD.md скопирован из `kvartal-app` → `kvartal_app` (объединение папок)
- `flutter analyze`: **0 issues**

#---

## Сессия 5 — 2026-05-27 — Claude

**Статус:** Окружение настроено, анализ проекта проведён, к коду не прикасались

### Сделано
- Установлен Obsidian v1.12.7, создан vault `C:\Users\crypt\ObsidianVault\`
- Настроена MCP-интеграция: Obsidian Local REST API + filesystem сервер → `C:\Users\crypt\.claude\settings.json`
- Настроен звуковой хук-уведомление при ожидании подтверждения (notify.wav)
- Создана база знаний проекта в Obsidian (7 заметок):
  - `КВАРТАЛ — Главная.md`
  - `Projects/Текущий код — что сделано.md`
  - `Projects/Архитектура Flutter.md`
  - `Projects/Экраны приложения.md`
  - `Projects/Дизайн-система.md`
  - `Projects/Дорожная карта.md`
  - `Architecture/Backend — план.md`
  - `Architecture/Стек 2026 — Лучшие инструменты.md`
  - `Architecture/Анализ проекта — что менять.md`
- Проведён полный анализ всего кода (все 9 Dart-файлов прочитаны)

### Проверка
- `flutter analyze` в этой сессии не запускался (код не менялся)
- Последняя известная проверка: 0 issues (Сессия 3)

### Критические проблемы (приоритет для следующей сессии)
1. ❌ Нет `h3_dart` — гексагоны не реализованы (HERO FEATURE)
2. ❌ Нет `flutter_background_geolocation` — GPS пропадает при блокировке экрана
3. ❌ Нет backend/Supabase — все данные хардкод
4. ❌ Нет `freezed` — модели мутабельные
5. ⚠️ `flutter_animate` и `fl_chart` установлены но не используются нигде

### Следующее
Приоритет 1: добавить `h3_dart`, нарисовать гексагоны поверх карты, реализовать логику захвата.
Подробный план — в Obsidian: `Architecture/Анализ проекта — что менять.md`

---

---

## Сессия 6 — 2026-05-27/28 — Claude
**Статус:** Go-бэкенд готов, реальные кварталы OSM на карте, тестирование через USB

### Сделано

#### Go-бэкенд (`backend/`)
- Инициализирован Go-модуль `kvartal/backend`, установлен Fiber v2
- Создан `backend/main.go` — HTTP-сервер на порту 3000:
  - CORS для всех источников
  - `GET /api/zones` — отдаёт кварталы
  - `POST /api/zones/reload` — принудительное обновление
  - Асинхронная загрузка при старте (сервер не блокируется)
  - Фоновое обновление каждые 12 часов
- Создан `backend/osm/osm.go`:
  - `LoadZones()` — пробует Overpass API, при сбое → OSM API напрямую
  - Парсинг XML от OSM API (`encoding/xml`)
  - Фильтр по тегам: landuse, leisure, natural, amenity
  - `validBlock()` — фильтр по размеру (~50м–1км)
  - `removeContainers()` — убирает зоны-контейнеры
  - `LoadZonesCached()` — статик-файл → runtime-кэш → живой API
  - `FallbackZones()` убран полностью

#### Данные OSM
- Скачан OSM XML центра Якутска через `api.openstreetmap.org/api/0.6/map`
  (bbox: 129.695,62.010,129.765,62.048 — ~13 МБ)
- Обработан Python-скриптом: 226 raw → 213 кварталов после фильтрации
- Сохранён как `backend/yakutsk_zones.json` — статический файл, мгновенная загрузка без интернета
- Это **реальные OSM-полигоны** с реальными границами улиц (не прямоугольники)

#### Flutter (`lib/features/map/data/zone_provider.dart`)
- Полностью убраны fallback-квадраты (`_buildFallback`, `_mockOwner`, `_nsStreets`, `_ewStreets`)
- Провайдер переведён на `AsyncValue<List<BlockZone>>` (loading / data / error)
- `_init()` опрашивает бэкенд каждые 5 секунд пока не загрузит данные (503 = сервер ещё грузит)
- URL бэкенда: `http://localhost:3000/api/zones`

#### Flutter (`lib/features/map/presentation/screens/map_screen.dart`)
- Обновлён под `AsyncValue` — показывает спиннер при загрузке
- Добавлен баннер ошибки если сервер недоступен

#### Сеть и запуск
- Создано правило Windows Firewall для порта 3000 (Profile: Any)
- Настроен ADB reverse port forwarding (`adb reverse tcp:3000 tcp:3000`)
  — телефон обращается к серверу через USB, WiFi firewall не мешает
- Собран `kvartal_server.exe` — готовый бинарник для запуска

### Текущее состояние
- Сервер: `backend/kvartal_server.exe` — 213 кварталов, мгновенный старт
- Приложение: подключается к `localhost:3000` через ADB reverse
- `dart analyze lib/features/map/` — 0 issues
- APK собран и установлен на телефон (device: 143332557B103525)

### Как запускать для тестирования
```
# 1. Запустить сервер
cd C:\Users\crypt\kvartal_app\backend
.\kvartal_server.exe

# 2. Пробросить порт через USB (в другом терминале)
C:\Android\platform-tools\adb.exe reverse tcp:3000 tcp:3000

# 3. Открыть приложение на телефоне
```

### Следующие шаги
- [ ] Авторизация (SMS-вход)
- [ ] Захват территорий при реальной пробежке (проверить на улице)
- [ ] Сохранение захваченных зон между запусками (сейчас сбрасываются)
- [ ] PostgreSQL для постоянного хранения данных и мультиюзера
- [ ] H3-гексагоны как альтернатива OSM-кварталам (если нужна равномерность)

---

## Следующие шаги (Sprint 1 финал)
- [ ] Авторизация (экран входа по SMS)
- [ ] H3-гексагоны на карте (h3_dart пакет)
- [ ] Сохранение завершённых пробежек (SharedPreferences)
- [ ] Go-бэкенд (базовый API)

### Технические решения
- `MaterialApp.router` с `GoRouter` — для ShellRoute (сохраняет состояние табов)
- `NoTransitionPage` для переключения табов без анимации
- `SliverAppBar` на ProfileScreen — красивый коллапс хедера
- Кастомный NavBar вместо `BottomNavigationBar` — для pill-кнопки "Бег"

---

## Сессия 4 — 2026-05-27 — Codex
**Статус:** настроен протокол совместной работы Claude + Codex

### Сделано
- Найдена актуальная рабочая директория проекта: `C:\Users\crypt\kvartal_app`.
- Зафиксировано, что старая папка `C:\Users\crypt\kvartal-app` больше не является рабочей директорией.
- Прочитаны Claude memory и проектные файлы `AGENTS.md`, `CLAUDE.md`, `HISTORY.md`.
- Добавлен `CODEX_HANDOFF.md` — общий файл передачи смены между Claude и Codex.
- Добавлена отдельная запись сессии `CODEX_SESSION_2026-05-27.md`.

### Проверка
- Код приложения не изменялся.
- `flutter analyze` в этой сессии не запускался.
- Последняя известная проверка по истории Claude: `flutter analyze` — 0 issues.

### Следующее
- Следующему агенту сначала прочитать `CODEX_HANDOFF.md`, затем последнюю запись `HISTORY.md`.
- Запустить `flutter analyze`.
- Сверить фактическое состояние H3/auth/zone файлов с историей.
- Продолжить Sprint 1: H3-гексагоны на карте или сохранение завершённых пробежек.

---

## Сессия 7 — 2026-05-28 — Codex
**Статус:** сохранение захваченных зон добавлено в Flutter

### Сделано
- Прочитаны `AGENTS.md`, `CODEX_HANDOFF.md`, последняя история и фактические файлы проекта.
- Подтверждено текущее состояние после Claude: Go-бэкенд отдаёт OSM-зоны, Flutter-захват зон уже работает через `ZoneNotifier.checkAndCaptureLoop()`.
- В `lib/features/map/data/zone_provider.dart` добавлено локальное сохранение захваченных пользователем зон:
  - id зон со статусом `mine` сохраняются в `SharedPreferences` по ключу `kvartal.captured_zone_ids.v1`;
  - при загрузке зон с бэкенда сохранённые id накладываются поверх данных сервера как `ZoneOwner.mine`;
  - `reset()` больше не теряет сохранённые захваты, а восстанавливает их поверх исходного состояния.

### Проверка
- `C:\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\features\map\data\zone_provider.dart` — успешно.
- `C:\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\features\map` — `No issues found!`
- Обычный wrapper `dart` зависал из-за попытки Dart CLI создать `C:\Users\crypt\AppData\Roaming\.dart-tool` в sandbox; использован прямой SDK-бинарник с разрешением на запись служебных файлов.

### Следующее
- Проверить сохранение на устройстве: запустить `backend\kvartal_server.exe`, сделать демо-захват/реальный захват, перезапустить приложение и убедиться, что зоны остаются `mine`.
- Следующий крупный шаг: SMS-авторизация или перенос состояния зон на сервер/PostgreSQL для мультипользовательского режима.

---

## Сессия 8 — 2026-05-28 — Codex
**Статус:** демо-бег обновлён под текущую механику и свежая сборка установлена на телефон

### Сделано
- В `lib/features/map/data/zone_provider.dart` добавлен `buildDemoRunPath()`:
  - маршрут демо строится по реально загруженным OSM-зонам;
  - выбираются ближайшие незахваченные зоны;
  - прямоугольный маршрут автоматически расширяется до дистанции, достаточной для текущей логики захвата.
- В `lib/features/map/presentation/screens/map_screen.dart` демо-бег теперь:
  - рисует демо-маршрут на карте;
  - показывает демо-дистанцию, время и статус захвата в нижней панели;
  - использует реальный `checkAndCaptureLoop()`, а не отдельную декоративную имитацию;
  - после завершения сохраняет захваченные зоны через существующий слой `SharedPreferences`.
- Собран свежий APK и установлен на телефон `143332557B103525`.
- Настроен `adb reverse tcp:3000 tcp:3000`.

### Проверка
- `C:\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\features\map\data\zone_provider.dart lib\features\map\presentation\screens\map_screen.dart` — успешно.
- `C:\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\features\map` — `No issues found!`
- `C:\flutter\bin\flutter.bat build apk --debug` — успешно, APK: `build\app\outputs\flutter-apk\app-debug.apk`.
- `adb install -r build\app\outputs\flutter-apk\app-debug.apk` — `Success`.
- Go-бэкенд в foreground отдавал `GET /api/zones` с 213 зонами; скрытый запуск через `Start-Process` в этой среде не удержался, поэтому для ручного теста сервер нужно держать открытым отдельным терминалом.

### Следующее
- Запустить `backend\kvartal_server.exe` в отдельном PowerShell и нажать в приложении `Демо бег`.
- После проверки демо можно продолжить визуальный редизайн в Apple-like стиле: системный шрифт, новый таббар, новый бренд `КВАРТАЛ` и более чистая карта.

---

## Сессия 9 — 2026-05-28 — Codex
**Статус:** первый визуальный редизайн frontend выполнен и установлен на телефон

### Сделано
- Обновлена визуальная база приложения:
  - бренд в коде и UI переведён на `КВАРТАЛ`;
  - `AppStrings` приведён к нормальному UTF-8 с русскими названиями табов;
  - тема переведена с `GoogleFonts.nunito` на системный шрифт, ближе к iOS/San Francisco;
  - цвета обновлены на более премиальную iOS dark-палитру: `#000000`, `#1C1C1E`, `#2C2C2E`, `#8E8E93`;
  - снижена избыточная жирность типографики, убраны агрессивные отрицательные letter spacing.
- Обновлён нижний таббар:
  - добавлен Cupertino icon set;
  - стеклянная панель стала чище;
  - центральная кнопка бега стала менее игровой и более нативной.
- Обновлён верх карты:
  - вместо капсового `КВАРТАЛ` теперь аккуратный `КВАРТАЛ`;
  - добавлен компактный бренд-знак;
  - стеклянные панели стали темнее и премиальнее;
  - часть Material-иконок заменена на Cupertino.
- Собран и установлен свежий debug APK на телефон `143332557B103525`.

### Проверка
- `C:\flutter\bin\cache\dart-sdk\bin\dart.exe format ...` — успешно.
- `C:\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib` — `No issues found!`
- `C:\flutter\bin\flutter.bat build apk --debug` — успешно.
- `adb install -r build\app\outputs\flutter-apk\app-debug.apk` — `Success`.
- Приложение запущено на телефоне через `adb shell monkey`.

### Следующее
- Второй визуальный проход: полностью переработать экраны `RunScreen`, `LeaderboardScreen`, `ProfileScreen` в новом премиальном стиле, уже не только глобальный слой и карту.
- Отдельно подготовить новую иконку приложения: тёмный фон, синий маршрут-петля, маленькая GPS-точка.
## Сессия 11 — 2026-06-03 — Codex
**Статус:** проведён обзор текущего состояния проекта без изменения кода

### Сделано
- Прочитаны `AGENTS.md`, `CODEX_HANDOFF.md`, последние записи `HISTORY.md` и ключевые файлы Flutter/Go.
- Сверена фактическая структура проекта: Flutter-приложение с 5 вкладками, моковая SMS-авторизация, карта с OSM/кварталами, базовый GPS-трекинг, Go API для зон.
- Проверено, что русские строки в файлах сохранены как нормальный UTF-8; кракозябры появляются из-за вывода PowerShell, а не из-за порчи файлов.
- Зафиксировано, что в текущей папке нет активного `.git`, поэтому `git status` недоступен.

### Проверка
- `go test ./...` в `backend/` — успешно, тестовых файлов нет.
- `C:\flutter\bin\flutter.bat analyze` завис без вывода; процесс был завершён вручную. Результат анализа Flutter в этой сессии не получен.

### Следующее
- Запустить Flutter-анализ из IDE/обычного терминала или через прямой Dart SDK, как в предыдущих сессиях.
- Приоритетно решить: реальная авторизация/сессия, сохранение завершённых пробежек, единый источник территорий (H3 или OSM-кварталы), серверное хранение зон и пользователей.
## Сессия 12 — 2026-06-03 — Codex
**Статус:** улучшены захват территории и устойчивость GPS-маршрута

### Сделано
- `lib/features/run/data/run_provider.dart`:
  - активная/последняя пробежка сохраняется в `SharedPreferences` по ключу `kvartal.active_run.v1`;
  - маршрут, дистанция, время и статус восстанавливаются после перезапуска приложения;
  - если пробежка была активной, после восстановления заново запускаются таймер и GPS stream;
  - для Android включены `AndroidSettings` с foreground notification, wake lock и интервалом GPS 3 секунды.
- `android/app/src/main/AndroidManifest.xml`:
  - добавлено разрешение `android.permission.FOREGROUND_SERVICE_LOCATION`.
- `lib/features/map/data/zone_provider.dart`:
  - захват замкнутого периметра стал быстрее: минимум периметра снижен до 150 м, допустимый зазор закрытия — 120 м;
  - полигон явно замыкается перед проверкой центров зон внутри маршрута.

### Проверка
- `dart format lib\features\map\data\zone_provider.dart lib\features\run\data\run_provider.dart` — успешно.
- `dart analyze lib\features\run\data\run_provider.dart lib\features\map\data\zone_provider.dart` — 0 issues.
- `dart analyze lib` — 0 issues.
- `dart pub get` — успешно.
- `flutter build apk --debug` после `flutter clean` не прошёл из-за ошибки записи shader-файла `build\app\intermediates\flutter\debug\flutter_assets\shaders/ink_sparkle.frag`. Похоже на проблему Flutter shader compiler/окружения с текущим путём проекта, а не на Dart/manifest ошибку.

### Следующее
- Проверить на телефоне: начать пробежку, свернуть/заблокировать телефон, вернуться в приложение и убедиться, что маршрут продолжается/восстанавливается.
- Если Android всё равно убивает процесс полностью, следующим шагом подключать настоящий background service package, потому что foreground notification в `geolocator` снижает шанс убийства Activity, но не гарантирует работу после полного уничтожения процесса.
- Для сборки APK попробовать временно собрать проект из пути без кириллицы или разобраться с `impellerc` shader write error.
## Сессия 13 — 2026-06-03 — Codex
**Статус:** проект найден по новому пути, APK собран и установлен на телефон

### Сделано
- Найден актуальный путь после переименования корневой папки: `D:\MyProjectsCLAUDE\kvartal-app`.
- Собран debug APK из пути без кириллицы.
- APK установлен на телефон `143332557B103525`.
- Настроен `adb reverse tcp:3000 tcp:3000`.
- Запущен локальный Go backend из `D:\MyProjectsCLAUDE\kvartal-app\backend\kvartal_server.exe`.
- Проверен backend health: `{"status":"ok","zones":213}`.
- Приложение запущено на телефоне через `adb shell monkey`.

### Проверка
- `flutter build apk --debug` — успешно, APK: `build\app\outputs\flutter-apk\app-debug.apk`.
- `adb install -r build\app\outputs\flutter-apk\app-debug.apk` — `Success`.
- `adb reverse tcp:3000 tcp:3000` — успешно.
- `GET http://localhost:3000/health` — 213 зон.

### Следующее
- На телефоне проверить новую механику: замкнутый периметр должен быстрее захватывать зоны внутри.
- Проверить GPS-маршрут: начать пробежку, свернуть/заблокировать телефон, вернуться в приложение и убедиться, что маршрут сохраняется/восстанавливается.
## Сессия 14 — 2026-06-03 — Codex
**Статус:** добавлена синяя заливка захваченного периметра и контроль возврата к старту

### Сделано
- `zone_provider.dart`:
  - добавлены `CapturedArea` и `LoopClosureStatus`;
  - захваченные контуры сохраняются в `SharedPreferences` по ключу `kvartal.captured_areas.v1`;
  - при успешном замыкании маршрута сохраняется не только список OSM-зон, но и сам полигон пробежки для синей заливки;
  - добавлен `inspectLoopClosure()` для расчёта дистанции маршрута и зазора до стартовой точки;
  - `checkAndCaptureLoop()` получил `forceClose`, чтобы можно было вручную подтвердить возврат к старту при GPS-погрешности.
- `map_screen.dart`:
  - добавлен слой синих залитых контуров поверх карты;
  - линия маршрута сделана тоньше;
  - добавлены маркеры `Старт` и `Сейчас/Финиш`;
  - в нижней панели во время бега вместо темпа показывается расстояние до старта.
- `run_screen.dart`:
  - диалог завершения показывает расстояние до старта;
  - если GPS не замкнул петлю, но пользователь фактически вернулся, есть кнопка `Я вернулся к старту`;
  - при завершении/подтверждении выполняется захват и переход на карту.

### Проверка
- `dart format` изменённых файлов — успешно.
- `dart analyze lib\features\map\data\zone_provider.dart lib\features\map\presentation\screens\map_screen.dart lib\features\run\presentation\screens\run_screen.dart` — 0 issues.
- `dart analyze lib` — 0 issues.
- `flutter build apk --debug` — успешно.
- `adb install -r build\app\outputs\flutter-apk\app-debug.apk` — `Success`.
- `adb reverse tcp:3000 tcp:3000` — успешно.
- Backend `/health` — `{"status":"ok","zones":213}`.
- Приложение запущено на телефоне через `adb shell monkey`.

### Следующее
- На телефоне проверить: после завершения замкнутого маршрута внутри контура должна появиться синяя заливка.
- Проверить сценарий GPS-погрешности: если до старта осталось несколько метров, нажать `Я вернулся к старту` и убедиться, что заливка появилась.
## Сессия 15 — 2026-06-03 — Codex
**Статус:** исправлен захват любого замкнутого контура вне зависимости от OSM-зон

### Сделано
- `zone_provider.dart`:
  - сохранение синей заливки теперь не зависит от наличия OSM-зон в месте пробежки;
  - `checkAndCaptureLoop()` сначала сохраняет сам полигон пробежки как `CapturedArea`, а перекраску OSM-зон делает только дополнительно;
  - минимальный периметр для захвата снижен со 150 м до 50 м, чтобы круг вокруг небольшого дома тоже считался захватом.

### Проверка
- `dart analyze lib` — 0 issues.
- `flutter build apk --debug` — успешно.
- `adb install -r build\app\outputs\flutter-apk\app-debug.apk` — `Success`.
- Backend `/health` — `{"status":"ok","zones":213}`.
- Приложение запущено на телефоне через `adb shell monkey`.

### Следующее
- Протестировать: в любой части города замкнутый круг/квадрат должен давать синюю заливку по периметру, даже если рядом нет цветных OSM-квадратов.
## Сессия 16 — 2026-06-03 — Codex
**Статус:** исправлен overflow у маркеров старта/финиша

### Сделано
- `map_screen.dart`:
  - маркеры `Старт` и `Сейчас/Финиш` стали компактными круглыми значками без текстовой подписи на карте;
  - предупреждение `overflowed by ... pixels` больше не должно отображаться;
  - маркеры старта/финиша теперь показываются только во время активной или поставленной на паузу пробежки (`RunStatus != idle`), после завершения исчезают.

### Проверка
- `dart analyze lib` — 0 issues.
- `flutter build apk --debug` — успешно.
- `adb install -r build\app\outputs\flutter-apk\app-debug.apk` — `Success`.
- Backend `/health` — 213 зон.
- Приложение запущено на телефоне.

### Следующее
- Проверить на телефоне: во время пробежки видны только компактные старт/финиш точки без overflow-текста; после завершения они исчезают.
## Сессия 17 — 2026-06-04 — Codex
**Статус:** после завершения пробежки активный маршрут очищается

### Сделано
- `run_provider.dart`:
  - `stop()` теперь сбрасывает `RunState` в пустое состояние и удаляет `kvartal.active_run.v1`;
  - после завершения пробежки старт/финиш и старый активный маршрут не должны восстанавливаться на карте;
  - захваченная синяя территория не затрагивается, потому что хранится отдельно в `kvartal.captured_areas.v1`.

### Проверка
- `dart analyze lib` — 0 issues.
- `flutter build apk --debug` — успешно.
- `adb install -r build\app\outputs\flutter-apk\app-debug.apk` — `Success`.
- Backend `/health` — 213 зон.
- Приложение запущено на телефоне.

### Следующее
- Проверить: после завершения пробежки на карте остаётся только синяя заливка территории, а старт/финиш исчезают.
## Сессия 18 — 2026-06-04 — Codex
**Статус:** старые точки старта/финиша принудительно убраны

### Сделано
- `map_screen.dart`:
  - линия маршрута и маркеры старт/финиш теперь рисуются только при `RunStatus != idle`;
  - завершённая пробежка больше не может показывать старые точки по одному лишь сохранённому `route`.
- `run_provider.dart`:
  - добавлена версия схемы сохранённой активной пробежки (`schemaVersion = 2`);
  - старые сохранённые маршруты без новой схемы очищаются при запуске приложения;
  - сохранённая пробежка со статусом `idle` или пустым маршрутом также очищается.

### Проверка
- `dart analyze lib` — 0 issues.
- `flutter build apk --debug` — успешно.
- `adb install -r build\app\outputs\flutter-apk\app-debug.apk` — `Success`.
- Backend `/health` — 213 зон.
- Приложение запущено на телефоне.

### Следующее
- Проверить на телефоне: до нажатия `Начать` старые старт/финиш точки не должны отображаться; синяя захваченная территория должна остаться.

## Сессия 19 — 2026-06-04 — Codex
**Статус:** захват территории переведён на подтверждение после завершения пробежки

### Сделано
- `map_screen.dart`:
  - убран автозахват во время бега: карта больше не вызывает `checkAndCaptureLoop()` на каждой новой GPS-точке;
  - во время активной пробежки показывается только фактическая линия маршрута, без прямой линии к старту и без ранней заливки;
  - заливка сохранённых `CapturedArea` стала полупрозрачной (`alpha: 0.18`), граница тоже приглушена (`alpha: 0.70`);
  - восстановлен каркас `MapScreen` после повреждения regex-правкой, добавлены локальные функции цвета и демо-режим;
  - компактные старт/финиш маркеры остаются только при `RunStatus != idle`.
- `zone_provider.dart`:
  - порог замыкания контура установлен в 10 м;
  - удалён `forceClose`, теперь захват невозможен, если GPS-разрыв старт-финиш больше 10 м;
  - добавлен `capturedAreasProvider` для реактивного слоя сохранённых полигонов.
- `run_screen.dart`:
  - диалог завершения показывает дистанцию до старта по GPS;
  - кнопка `Захватить` активна только при `closure.canCapture` (`периметр >= 50 м` и `старт-финиш <= 10 м`);
  - ручная кнопка `Я вернулся к старту` удалена;
  - при незамкнутом контуре доступно `Продолжить` или `Завершить без захвата`, но заливка не создаётся.

### Проверка
- `dart format` — успешно.
- `dart analyze lib` — 0 issues.
- `flutter build apk --debug` — успешно.
- `adb install -r build\app\outputs\flutter-apk\app-debug.apk` — `Success`.
- `adb reverse tcp:3000 tcp:3000` — настроен.
- Backend `/health` — `{"status":"ok","zones":213}`.
- Приложение запущено на телефоне через `adb shell monkey`.

### Следующее
- Проверить на телефоне: во время бега территория не должна закрашиваться и не должно быть прямой линии к старту; после возврата в радиус 10 м и подтверждения `Захватить` должна появиться полупрозрачная синяя заливка.
## Сессия 20 — 2026-06-04 — Codex
**Статус:** исправлен live GPS для карты и записи маршрута

### Причина
После теста вокруг дома стартовая точка фиксировалась, но маркер на карте не двигался и маршрут не рисовался. В реализации карта брала `getCurrentPosition()` одноразово, а трекинг ждал обновления GPS с `distanceFilter: 5`, из-за чего Android мог долго блокировать точки как `too close`.

### Сделано
- `run_provider.dart`:
  - при старте пробежки сразу запрашивается текущая позиция и добавляется в маршрут;
  - GPS-stream переведён на `distanceFilter: 0` и интервал 1 сек на Android;
  - добавлена обработка ошибок GPS-stream через `debugPrint`, чтобы поток больше не отваливался молча;
  - `_onPosition` игнорирует точки, если пробежка уже не активна.
- `location_provider.dart`:
  - `positionStreamProvider` теперь сначала отдаёт текущую позицию, затем live-stream с `distanceFilter: 0`;
  - stream учитывает отсутствие разрешения и отдаёт `null`, а не падает.
- `map_screen.dart`:
  - GPS-маркер карты переведён с одноразового `currentPositionProvider` на live `positionStreamProvider`;
  - при включённом follow mode карта двигается за новой GPS-позицией.

### Проверка
- `dart format` — успешно.
- `dart analyze lib` — 0 issues.
- `flutter build apk --debug` — успешно.
- `adb install -r build\app\outputs\flutter-apk\app-debug.apk` — `Success`.
- `pm clear com.kvartal.kvartal_app` — данные очищены для нового теста.
- `adb reverse tcp:3000 tcp:3000` — настроен.
- Backend `/health` — `{"status":"ok","zones":213}`.
- Разрешения `ACCESS_FINE_LOCATION` и `ACCESS_COARSE_LOCATION` выданы через `adb pm grant`.
- Приложение запущено на телефоне.

### Следующее
- Повторить короткий тест на улице: после нажатия `Старт` маркер должен двигаться, линия маршрута должна расти. Если маршрут растёт, снова тестировать замыкание и полупрозрачный захват.
## Сессия 21 — 2026-06-04 — Codex
**Статус:** упрощены маркеры маршрута и увеличена GPS-погрешность замыкания

### Сделано
- `map_screen.dart`:
  - удалён маркер текущей/финишной точки маршрута;
  - во время пробежки на маршруте остаётся только маркер `Старт`, чтобы пользователь видел место возврата.
- `zone_provider.dart`:
  - `_maxLoopGapMeters` увеличен с 10 м до 20 м.
- `run_screen.dart`:
  - текст диалога завершения обновлён: для захвата нужно вернуться в радиус 20 м.

### Проверка
- `dart format` — успешно.
- `dart analyze lib` — 0 issues.
- `flutter build apk --debug` — успешно.
- `adb install -r build\app\outputs\flutter-apk\app-debug.apk` — `Success`.
- `adb reverse tcp:3000 tcp:3000` — настроен.
- Backend `/health` — `{"status":"ok","zones":213}`.
- Приложение запущено на телефоне.
## Сессия 22 — 2026-06-04 — Codex
**Статус:** добавлен foreground/background GPS service для активной пробежки

### Сделано
- `pubspec.yaml` / `pubspec.lock`:
  - добавлен `flutter_background_service: ^5.1.0`.
- `lib/features/run/data/background_run_service.dart`:
  - добавлен отдельный `BackgroundRunService`;
  - Android foreground service запускается с `foregroundServiceTypes: [AndroidForegroundType.location]`;
  - сервис читает/пишет активную пробежку в `SharedPreferences` (`kvartal.active_run.v1`);
  - GPS-точки пишутся в фоне через `Geolocator.getPositionStream(...)`;
  - сервис обновляет foreground notification с текущей дистанцией;
  - сервис отправляет события `position` обратно в UI, если приложение открыто.
- `lib/features/run/data/run_provider.dart`:
  - `RunNotifier` больше не держит собственный `Geolocator` stream, чтобы не было дублей;
  - старт пробежки запускает `BackgroundRunService.start()`;
  - пауза/стоп останавливают GPS в сервисе;
  - UI синхронизируется с сохранённой активной пробежкой при событиях сервиса;
  - `_persistRun()` защищён от перезаписи более свежего маршрута, который уже сохранил background service.
- `lib/main.dart`:
  - сервис конфигурируется до `runApp()`.
- `android/app/src/main/AndroidManifest.xml`:
  - добавлен `POST_NOTIFICATIONS`;
  - добавлена декларация `id.flutter.flutter_background_service.BackgroundService` с `android:foregroundServiceType="location"`.

### Проверка
- `flutter pub get` — успешно.
- `dart format` — успешно.
- `dart analyze lib` — 0 issues.
- `flutter build apk --debug` — успешно.
- `adb install -r build\app\outputs\flutter-apk\app-debug.apk` — `Success`.
- `adb reverse tcp:3000 tcp:3000` — настроен.
- Backend `/health` — `{"status":"ok","zones":213}`.
- Runtime permissions на телефоне подтверждены:
  - `ACCESS_FINE_LOCATION: granted=true`;
  - `ACCESS_COARSE_LOCATION: granted=true`;
  - `ACCESS_BACKGROUND_LOCATION: granted=true`;
  - `POST_NOTIFICATIONS: granted=true`;
  - `FOREGROUND_SERVICE_LOCATION: granted=true`;
  - `WAKE_LOCK: granted=true`.
- Приложение запущено на телефоне.

### Следующее
- Полевой тест: нажать `Старт`, пройти/пробежать 20-30 м, свернуть приложение/заблокировать экран на 1-2 минуты, затем вернуться. Маршрут должен продолжить расти, а notification `КВАРТАЛ записывает пробежку` должен быть виден во время активной пробежки.
## Сессия 23 — 2026-06-04 — Codex
**Статус:** ребрендинг приложения на КВАРТАЛ

### Сделано
- Логотип:
  - выбран и сохранён прозрачный PNG: `assets/brand/kvartal-logo-transparent.png`;
  - исходники сохранены в `assets/brand/kvartal-logo-chromakey-fixed.png` и `assets/brand/kvartal-logo-sheet-selected.png`;
  - launcher icons Android (`mipmap-* / ic_launcher.png`) пересобраны из прозрачного логотипа на тёмном графитовом фоне.
- Название:
  - `AppStrings.appName` заменён на `КВАРТАЛ`;
  - Android `android:label` заменён на `КВАРТАЛ`;
  - видимые тексты `КВАРТАЛ/КВАРТАЛ` заменены на `КВАРТАЛ` в splash, auth, run, profile и notification-текстах;
  - технический `applicationId/namespace com.kvartal.kvartal_app` оставлен без изменения, чтобы APK устанавливался поверх текущего приложения.
- UI/анимация:
  - добавлен `lib/shared/widgets/kvartal_logo.dart` с `KvartalLogoMark` и `KvartalLogoBadge`;
  - логотип встроен в splash screen с новой анимацией появления;
  - логотип встроен в верхний чип карты;
  - логотип встроен в шапку экрана тренировки;
  - стартовая карточка получила крупный анимированный логотип и новую графит/терракота палитру;
  - центральная кнопка бега в bottom nav использует маленький логотип вместо pin-иконки.
- `pubspec.yaml`:
  - добавлен asset folder `assets/brand/`;
  - описание проекта обновлено на `КВАРТАЛ — городское беговое приложение для захвата территорий`.

### Проверка
- `dart format` — успешно.
- `dart analyze lib` — 0 issues.
- `flutter build apk --debug` — успешно.
- `adb install -r build\app\outputs\flutter-apk\app-debug.apk` — `Success`.
- `adb reverse tcp:3000 tcp:3000` — настроен.
- Backend `/health` — `{"status":"ok","zones":213}`.
- Приложение запущено на телефоне.

### Примечание
- Package id пока остаётся `com.kvartal.kvartal_app`. Менять его стоит отдельным шагом ближе к публикации, потому что это создаст новое приложение для Android и повлияет на установку/данные.
## Сессия 24 — 2026-06-04 — Codex
**Статус:** исправлен seamless launch/splash переход логотипа

### Причина
При запуске приложения пользователь видел разрыв: сначала системный/другой фон и логотип, затем Flutter splash с другим фоном/цветом и отдельной анимацией. Нужно было сделать старт как в премиальных приложениях: один и тот же логотип начинает анимироваться без визуального скачка.

### Сделано
- Android native splash:
  - создан `android/app/src/main/res/drawable/launch_logo.png` из прозрачного логотипа `assets/brand/kvartal-logo-transparent.png`;
  - добавлен `android/app/src/main/res/values/colors.xml` с `launch_background=#000000`;
  - `drawable/launch_background.xml` и `drawable-v21/launch_background.xml` теперь рисуют чёрный фон и тот же логотип по центру;
  - добавлен `values-v31/styles.xml` с Android 12+ splash атрибутами:
    - `android:windowSplashScreenBackground`;
    - `android:windowSplashScreenAnimatedIcon`;
    - `android:windowSplashScreenIconBackgroundColor`.
- Flutter splash:
  - убрана отдельная rounded-карточка вокруг логотипа;
  - первый Flutter-кадр теперь совпадает с native splash: чёрный фон + тот же логотип по центру;
  - анимация начинается сразу мягким premium pulse, без масштабирования из маленькой иконки;
  - время splash сокращено до 1900 мс.

### Проверка
- `dart format` — успешно.
- `dart analyze lib` — 0 issues.
- `flutter build apk --debug` — успешно.
- `adb install -r build\app\outputs\flutter-apk\app-debug.apk` — `Success`.
- `adb reverse tcp:3000 tcp:3000` — настроен.
- Backend `/health` — `{"status":"ok","zones":213}`.
- Приложение запущено на телефоне.

### Примечание
- `android:postSplashScreenTheme` в этом проекте не поддержался resource linker'ом, поэтому он удалён из `values-v31/styles.xml`. Остальные Android 12 splash атрибуты собираются успешно.
## Сессия 25 — 2026-06-04 — Codex
**Статус:** убрана белая splash-окантовка, удалён демо-бег, добавлена локальная история пробежек

### Сделано
- Android launch/icon:
  - создан adaptive icon `mipmap-anydpi-v26/ic_launcher.xml` и `ic_launcher_round.xml`;
  - добавлены `drawable/ic_launcher_background.xml` и `drawable/ic_launcher_foreground.png`;
  - foreground/launch logo пересобраны из прозрачного логотипа `assets/brand/kvartal-logo-transparent.png`;
  - из `values-v31/styles.xml` удалён `android:windowSplashScreenIconBackgroundColor`, чтобы Android не рисовал дополнительную системную плашку/окантовку вокруг splash icon.
- `map_screen.dart`:
  - полностью удалён демо-бег: кнопка `Демо бег`, виртуальный маршрут, demo marker, demo timer, demo stats и вызовы `checkAndCaptureLoop()` из demo-режима;
  - карта теперь показывает только реальные GPS/реальные пробежки.
- История завершённых пробежек:
  - добавлен `lib/features/run/data/completed_runs_provider.dart`;
  - завершённые пробежки сохраняются в `SharedPreferences` под ключом `kvartal.completed_runs.v1`;
  - сохраняются дата завершения, маршрут, дистанция, время, темп, факт захвата и число захваченных OSM-зон;
  - `RunNotifier.stop()` теперь сохраняет завершённую пробежку перед сбросом активного маршрута;
  - экран `RunScreen` больше не использует моковые `_recentRuns`, блок `Последние пробежки` читает реальные записи из `completedRunsProvider`.

### Проверка
- `dart format` — успешно.
- `dart analyze lib` — 0 issues.
- `flutter build apk --debug` — успешно.
- APK собран: `build\app\outputs\flutter-apk\app-debug.apk`.

### Примечание
- APK не установлен на телефон по просьбе пользователя: установка будет позже, когда телефон подключат.

---

## ?????? 26 ? 2026-06-09 ? Codex
**??????:** ????????? ????? backend-???????, phone auth ? backend-??????? ??? ???????; ???????????? ???????? ??????

### ???????
- ?????? ? ?????? ??? ????? backend ?????? `D:\MyProjectsCLAUDE\backend` (FastAPI + SQLite dev).
- ???????? ?????? ?????????? ???? `POST /v1/auth/phone/verify` ? dev-????? `1234`.
- ???????? ????? ??????? `PATCH /v1/profile` ? Bearer JWT.
- `GET /v1/auth/me` ?????????? ??????????? ???????, ??????? `city`.
- ? ??????? ???????? `lib/core/api/api_config.dart` ? `http://127.0.0.1:8000/v1` ??? debug/dev ????? `adb reverse tcp:8000 tcp:8000`.
- `lib/features/auth/data/auth_provider.dart` ? ??????? ????????? ?? backend phone auth, JWT-??? ? updateProfile ????? `/profile`.
- `lib/features/profile/presentation/screens/profile_screen.dart` ? ??????? ????????? ? ???????? ?? ???????? ?????? `authProvider.user`, ????????? ?????????????? ??????? ? ????? ????????.
- SportStore ???????? ??????????? ? ??????? ????????: ????????? `id`, provider `phone`, `loginByPhone`, UI-???? ????? ?? ????????, dev baseUrl ????? `127.0.0.1:8000`.
- ?????? ???? ???????? ??? Claude: `CLAUDE_HANDOFF_2026-06-09.md`.

### ????????
- ???????: `dart analyze lib` ? no issues.
- ???????: `flutter test` ? passed.
- ???????: `flutter build apk --debug` ? success.
- ???????: APK ?????????? ?? ??????? ? ??????? ????? ADB.
- SportStore ????? phone-auth ??????: `dart analyze lib` ? no issues; `flutter test` ? passed; debug APK ?????? ? ??????????.
- Backend: `python -m py_compile main.py` ? success.
- Backend API: ?????????, ??? ???? ????? ???????? ?????????? ???? ? ??? ?? `user_id`; `PATCH /v1/profile` ????????? ??????? ? `/auth/me` ?????? ??? ???????.

### ?????????
- ??????: ????????? `CLAUDE_HANDOFF_2026-06-09.md`.
- ????????? SportStore `AuthProvider.updateProfile(...)` ?? backend `PATCH /v1/profile`; ?????? ??????? SportStore ??? ??? ??????????? ? ???????? ????????.
- ??? ?????? SportStore ? JWT ??????????? ?????? ??????? ????? `GET /v1/auth/me`.
- ????????? ????????? ?????? `????` ? ????? ???????? SportStore, ??????????? ??-?? ????????? PowerShell.
- ????? sync ??????? ?????????: ???????? ???/?????/email ? ??????? ? ??????? ?? ?? ?????? ? SportStore ??? ????? ??? ?? ???????.


---

## Сессия — 2026-06-13: баллы экосистемы в профиле + кросс-апп тест на устройстве

**Статус:** Квартал и Store показывают один аккаунт и один баланс из общего бека. Проверено вживую на телефоне.

### Сделано
- Новый `lib/features/loyalty/data/loyalty_provider.dart` (Riverpod): читает общий баланс через `GET /v1/loyalty/account` с Bearer-токеном из authProvider. Состояние: balance/level/transactions, русское имя уровня (Базовый/Серебро/Золото/Платина по порогам 0/200/500/1000).
- `profile_screen.dart`: добавлена карточка «Баллы экосистемы» (баланс + уровень). Стиль — существующие AppColors/карточки, без нового дизайна. `ProfileScreen` переведён в ConsumerStatefulWidget и дёргает `loyaltyProvider.refresh()` в initState (всегда свежий баланс при открытии профиля).
- В loyalty-Dio добавлен заголовок `Connection: close` + дедуп одновременных refresh — лечит "Connection closed before full header" поверх adb reverse (Dio переиспользует keep-alive, который uvicorn закрывает).

### Грабли
- Симптом "Connection closed before full header / DioException" оказался следствием упавшего backend (порт 8000 не слушался). Бек перезапускать: `cd backend && PYTHONUNBUFFERED=1 python -m uvicorn main:app --host 0.0.0.0 --port 8000` + `adb reverse tcp:8000 tcp:8000`.

### Проверено на устройстве (Infinix X6873)
- Телефон пользователя **8 914 827 8470** -> нормализуется в `+79148278470` -> аккаунт `u_fbff802b3ddffc10` (Михаил Татаринов, runner_79148278470@kvartal.local).
- Квартал профиль: **430 / Серебро** из бека.
- Тот же аккаунт открыт в SportStore: то же имя/email, **430 баллов / Серебро**.
- Начисление `POST /v1/loyalty/transactions +60` (как пробежка из Квартала) -> оба приложения после перезапуска показали **490**. Живой общий баланс экосистемы доказан.

### Дальше
- Начислять баллы из Квартала автоматически (по факту пробежки/захвата зоны) -> `POST /loyalty/transactions` из run_provider/zone_provider.
- Подтянуть профильные статы (км/зоны/пробежки/победы) из бека вместо захардкоженных 0.

## 2026-06-13 - Strategic direction: GitHub + Django

- Project owner decided future work should move to GitHub workflow.
- Preferred structure is ecosystem monorepo: KVARTAL, SportStore, website/admin, shared backend, docs and infra.
- Backend migration direction changed from FastAPI prototype toward Django + Django REST Framework.
- Migration should be gradual: preserve current API contracts first, then switch apps to Django after verification.
- Added Cloud handoff: `CLAUDE_HANDOFF_GITHUB_DJANGO_2026-06-13.md`.

## 2026-06-13 - Docker noted for future infrastructure

- Project owner confirmed Docker is needed for the ecosystem, but later and step-by-step.
- Intended use: Django API, PostgreSQL/PostGIS, Redis, Celery worker/beat and deployment-like local environment.
- Docker should not block the current GitHub/monorepo setup or initial Django migration.
- Added Docker note to `CLAUDE_HANDOFF_GITHUB_DJANGO_2026-06-13.md`.

