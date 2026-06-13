# КВАРТАЛ — совместная работа Claude + Codex

Этот файл нужен, чтобы Claude и Codex могли продолжать проект по очереди: когда у одного агента заканчиваются лимиты, второй должен быстро понять текущее состояние и продолжить без потери контекста.

## Главный источник проекта

Актуальный проект находится здесь:

`D:\MyProjectsCLAUDE\kvartal-app`

Не путать со старой папкой:

`D:\MyProjectsCLAUDE\kvartal-app`

Старая папка с дефисом была промежуточной и больше не является рабочей директорией.

## Что читать перед началом работы

1. `AGENTS.md` — общие правила для всех агентов.
2. `CLAUDE.md` — соглашения, созданные Claude.
3. `CODEX_HANDOFF.md` — правила передачи работы между Claude и Codex.
4. `HISTORY.md` — хронология сессий и что было сделано.
5. `PRD.md` — продуктовые требования, если задача касается функций или UX.

Если задача техническая, дополнительно проверить:

- `pubspec.yaml`
- `lib/core/router/app_router.dart`
- `lib/features/map/data/`
- `lib/features/run/data/run_provider.dart`
- соответствующий экран в `lib/features/<feature>/presentation/`

## Правило передачи смены

После каждой рабочей сессии агент обязан оставить след:

1. Добавить запись в `HISTORY.md`.
2. Обновить раздел "Текущее состояние" в этом файле.
3. Указать, что проверено: `flutter analyze`, тесты, ручной запуск, либо честно написать, что не проверялось.
4. Оставить следующий конкретный шаг для второго агента.
5. Если были спорные решения, записать их в "Решения и договорённости".

Формат записи в `HISTORY.md`:

```md
## Сессия N — YYYY-MM-DD — AgentName
**Статус:** коротко

### Сделано
- ...

### Проверка
- ...

### Следующее
- ...
```

## Текущее состояние на 2026-05-28 (после Сессии 9 — Codex)

### Flutter-приложение
- Первый визуальный редизайн выполнен:
  - бренд в UI: `КВАРТАЛ`;
  - системный шрифт вместо Nunito;
  - iOS-like dark палитра в `AppColors`;
  - новый стеклянный таббар с Cupertino-иконками;
  - верх карты обновлён: компактный бренд-знак + `КВАРТАЛ`, более премиальные glass-панели
- `lib/features/map/data/zone_provider.dart` — получает зоны с Go-бэкенда через HTTP
  - Тип провайдера: `AsyncValue<List<BlockZone>>` (loading / data / error)
  - URL: `http://localhost:3000/api/zones`
  - Нет fallback-квадратов — только реальные OSM данные
  - Захваченные пользователем зоны сохраняются локально в `SharedPreferences`
  - Ключ хранения: `kvartal.captured_zone_ids.v1`
  - При новой загрузке зон сохранённые id восстанавливаются как `ZoneOwner.mine`
- `lib/features/map/presentation/screens/map_screen.dart` — спиннер при загрузке, баннер при ошибке
- Демо-бег на карте обновлён:
  - маршрут строится по текущим реальным OSM-зонам;
  - трек демо рисуется на карте;
  - нижняя панель показывает демо-дистанцию, время и захват;
  - используется текущая логика `checkAndCaptureLoop()` и сохранение через `SharedPreferences`
- `C:\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\features\map` — **0 issues**
- Свежий debug APK собран и установлен на телефон (device: 143332557B103525)

### Go-бэкенд (`backend/`)
- `backend/main.go` — Fiber v2, порт 3000, CORS, асинхронная загрузка
- `backend/osm/osm.go` — парсер OSM, кэш, статик-файл
- `backend/yakutsk_zones.json` — **213 реальных кварталов** центра Якутска (статический файл)
- `backend/kvartal_server.exe` — скомпилированный бинарник, готов к запуску
- Сервер стартует мгновенно (из `yakutsk_zones.json`)

### Как запускать для тестирования
```
# 1. Запустить сервер (держать открытым)
cd D:\MyProjectsCLAUDE\kvartal-app\backend
.\kvartal_server.exe

# 2. Пробросить порт через USB (в другом PowerShell)
C:\Android\platform-tools\adb.exe reverse tcp:3000 tcp:3000

# 3. Открыть приложение на телефоне
```

## Следующий рекомендуемый шаг для Codex

**Приоритет 1 — Второй визуальный проход:**
Переработать `RunScreen`, `LeaderboardScreen`, `ProfileScreen` под новый премиальный стиль, чтобы они не выглядели старее карты и таббара.

**Приоритет 2 — Ручная проверка демо на устройстве:**
Запустить `backend\kvartal_server.exe` в отдельном PowerShell, убедиться что `adb reverse tcp:3000 tcp:3000` активен, нажать `Демо бег` на карте и проверить: трек рисуется, зоны захватываются, после перезапуска остаются `mine`.

**Приоритет 3 — Авторизация (SMS):**
Экран авторизации есть как скелет в `lib/features/auth/`. Нужно подключить настоящий SMS-вход (smsc.ru).

**Приоритет 4 — PostgreSQL:**
Сейчас данные нигде постоянно не хранятся на сервере. Нужна БД для мультиюзерного захвата зон.

## Решения и договорённости

- Рабочая директория: `D:\MyProjectsCLAUDE\kvartal-app`.
- Старую папку `kvartal-app` не использовать как источник истины.
- Основной стек остаётся Flutter + Riverpod + GoRouter + flutter_map + geolocator.
- Документы истории должны быть понятны и Claude, и Codex.
- Не полагаться только на скрытые `.claude` memory/session файлы: важное состояние проекта должно быть продублировано в репозитории.
- Для кириллицы избегать записи через PowerShell 5.1 простым `Set-Content`, потому что он может ломать кодировку. Предпочтительно использовать редактор/патч-инструмент или явную UTF-8 запись.

## Быстрая памятка для Codex

- Перед изменениями читать `AGENTS.md`, `CLAUDE.md`, `HISTORY.md`, этот файл.
- Работать малыми, проверяемыми шагами.
- Не перезаписывать работу Claude без необходимости.
- После изменений оставлять запись в `HISTORY.md`.

## Быстрая памятка для Claude

- Перед продолжением проверить этот файл и последнюю запись `HISTORY.md`.
- Если Codex внёс изменения, считать их частью основного проекта, а не временным экспериментом.
- Если решение Codex нужно изменить, записать причину в `HISTORY.md`, чтобы следующий агент понимал контекст.

---

## Обновление пути — 2026-06-03 (Сессия 10 — Claude)

Проект перенесён с C: на D: — новый рабочий путь:

`D:\MyProjectsCLAUDE\kvartal-app`

Старые пути C:\Users\crypt\kvartal_app и C:\Users\crypt\kvartal-app — **удалены**.

---

## Обзор состояния — 2026-06-03 (Сессия 11 — Codex)

Codex провёл обзор проекта без изменения кода приложения.

- В текущей папке нет активного `.git`; `git status` недоступен.
- Русские строки в файлах сохранены как нормальный UTF-8. Кракозябры появляются из-за вывода PowerShell, не из-за порчи файлов.
- `go test ./...` в `backend/` прошёл успешно, тестовых файлов нет.
- `C:\flutter\bin\flutter.bat analyze` завис без вывода и был завершён вручную; Flutter-анализ нужно повторить из IDE/обычного терминала или прямым SDK-способом.
- Фактическое состояние: карта и зоны уже живые для прототипа, авторизация моковая, рейтинги/клуб/профиль в основном статичные, завершённые пробежки не сохраняются, серверной БД нет.

Следующий рекомендуемый шаг: выбрать ближайшую цель — либо довести визуал экранов и ручную демо-проверку, либо начать технический фундамент для реального MVP: auth/session, сохранение пробежек, серверное состояние зон.

---

## Обновление GPS/захвата — 2026-06-03 (Сессия 12 — Codex)

По замечаниям после ручного теста:

- `RunNotifier` теперь сохраняет активную/последнюю пробежку в `SharedPreferences` (`kvartal.active_run.v1`) и восстанавливает маршрут, дистанцию, время и статус после перезапуска.
- Если сохранённая пробежка была активной, при восстановлении снова запускаются таймер и GPS stream.
- Android GPS stream переведён на `AndroidSettings` с foreground notification, `enableWakeLock: true`, `setOngoing: true`, интервал 3 секунды.
- В `AndroidManifest.xml` добавлено `android.permission.FOREGROUND_SERVICE_LOCATION`.
- Захват территории стал быстрее: минимум замкнутого маршрута снижен до 150 м, допустимый зазор закрытия — 120 м, маршрут явно замыкается перед проверкой зон внутри.

Проверено:

- `dart analyze lib` — 0 issues.
- `dart format` изменённых файлов — успешно.
- `dart pub get` — успешно.
- `flutter build apk --debug` после `flutter clean` не прошёл из-за `Could not write file ... shaders/ink_sparkle.frag`. Похоже на проблему `impellerc`/окружения с текущим путём проекта на `D:\Мои проекты CLAUDE\...`, а не на ошибку Dart-кода.

Важно: foreground notification в `geolocator` помогает Android не убивать Activity в фоне, но не гарантирует трекинг после полного убийства процесса. Если тест на телефоне покажет, что маршрут всё ещё теряется при полном закрытии системой, следующий технический шаг — подключить полноценный background service package.

---

## Обновление пути и установка — 2026-06-03 (Сессия 13 — Codex)

Актуальный рабочий путь после переименования корневой папки:

`D:\MyProjectsCLAUDE\kvartal-app`

Сборка из нового пути прошла успешно:

- `flutter build apk --debug` — успешно.
- APK установлен на телефон `143332557B103525` через `adb install -r`.
- `adb reverse tcp:3000 tcp:3000` настроен.
- Go backend запущен из `backend\kvartal_server.exe`.
- `/health` отдаёт `{"status":"ok","zones":213}`.
- Приложение запущено на телефоне через `adb shell monkey`.

Следующее: ручной тест на телефоне — захват замкнутого периметра и сохранение/восстановление GPS-маршрута после сворачивания или блокировки.
---

## Захваченные контуры — 2026-06-03 (Сессия 14 — Codex)

Добавлен отдельный слой заливки захваченной территории: после замкнутого маршрута сохраняется CapturedArea в SharedPreferences (ugun.captured_areas.v1) и рисуется синим полигоном поверх карты. Линия маршрута стала тоньше. На маршруте есть маркеры Старт и Сейчас/Финиш. В диалоге завершения пробежки показывается расстояние до старта; если GPS промахнулся, кнопка Я вернулся к старту вызывает checkAndCaptureLoop(..., forceClose: true). APK собран, установлен на телефон 143332557B103525, backend доступен: 213 зон.

---

## Исправление независимого захвата — 2026-06-03 (Сессия 15 — Codex)

Захват синей заливки больше не зависит от OSM-зон. checkAndCaptureLoop() сохраняет CapturedArea при любом замкнутом маршруте от 50 м, а OSM-зоны перекрашивает только если они есть внутри. APK собран и установлен на телефон.

---

## Обновление захвата по подтверждению — 2026-06-04 (Сессия 19 — Codex)

По замечаниям ручного теста изменена логика захвата:

- Во время пробежки `map_screen.dart` больше не делает автоматический `checkAndCaptureLoop()` на новых GPS-точках. Рисуется только фактический маршрут.
- Территория окрашивается только в диалоге завершения пробежки, после подтверждения `Захватить`.
- Условие захвата строгое: `LoopClosureStatus.canCapture`, то есть маршрут не короче 50 м и GPS-разрыв между стартом и финишем не больше 10 м.
- `forceClose` удалён из `zone_provider.dart`; ручного обхода для замыкания при GPS-разрыве больше нет.
- Заливка `CapturedArea` стала полупрозрачной: синий `alpha 0.18`, граница `alpha 0.70`.
- Добавлен `capturedAreasProvider`, чтобы слой сохранённых полигонов обновлялся через Riverpod.
- APK собран, установлен на телефон, backend health: 213 зон, `adb reverse tcp:3000 tcp:3000` настроен.

Следующий тест: начать пробежку, обежать контур, убедиться, что во время бега нет ранней заливки и прямой линии к старту; вернуться в радиус 10 м, нажать завершение и подтвердить `Захватить`.
---

## Обновление live GPS — 2026-06-04 (Сессия 20 — Codex)

После ручного теста пользователь сообщил, что при старте фиксируется точка, но GPS-маркер не движется, маршрут не рисуется и территория не захватывается.

Изменения:
- `RunNotifier.start()` теперь сразу вызывает `_seedStartPosition()`, чтобы первая точка попадала в route без ожидания следующего stream event.
- `RunNotifier` GPS-stream: Android `distanceFilter: 0`, `intervalDuration: 1s`, добавлен `onError` с `debugPrint`.
- `location_provider.dart`: `positionStreamProvider` стал live-потоком `Position?`, сначала отдаёт `getCurrentPosition()`, затем `getPositionStream(distanceFilter: 0)`.
- `map_screen.dart`: пользовательский GPS-маркер теперь смотрит `positionStreamProvider`, а не одноразовый `currentPositionProvider`; при `_followUser` карта двигается за live-позицией.
- Новый APK собран/установлен, данные очищены, `adb reverse tcp:3000 tcp:3000` настроен, FINE/COARSE location выданы через adb.

Следующий тест: проверить именно движение маркера и рост линии маршрута после `Старт`; только потом снова проверять захват контура.
---

## Обновление маркеров и GPS-порога — 2026-06-04 (Сессия 21 — Codex)

По успешному тесту захвата пользователь попросил убрать финишную/текущую иконку, которая появлялась сразу после старта, и увеличить допустимую GPS-погрешность.

Изменения:
- На карте во время пробежки теперь отображается только маркер `Старт`; маркер `Сейчас/Финиш` удалён.
- Порог замыкания контура `_maxLoopGapMeters` увеличен с 10 м до 20 м.
- Текст диалога завершения теперь говорит про радиус 20 м.
- APK собран, установлен на телефон, backend health: 213 зон, `adb reverse tcp:3000 tcp:3000` настроен.
---

## Foreground/background GPS service — 2026-06-04 (Сессия 22 — Codex)

Добавлен полноценный Android foreground service для записи активной пробежки в фоне.

Ключевые изменения:
- Зависимость: `flutter_background_service: ^5.1.0`.
- Новый файл: `lib/features/run/data/background_run_service.dart`.
- `RunNotifier` теперь запускает/останавливает `BackgroundRunService`; собственный `Geolocator` stream из `RunNotifier` удалён, чтобы не дублировать точки.
- Сервис пишет активную пробежку в `SharedPreferences` под старым ключом `kvartal.active_run.v1`, schema version осталась `2`.
- Сервис обновляет notification и отправляет `position` events в UI.
- `main.dart` вызывает `await BackgroundRunService.configure()` до `runApp()`.
- Manifest содержит `POST_NOTIFICATIONS` и `<service android:name="id.flutter.flutter_background_service.BackgroundService" android:exported="true" android:foregroundServiceType="location" />`.
- Важно: `exported=true` оставлен, потому что plugin manifest тоже объявляет `true`; `false` ломает manifest merge.

Проверено:
- `dart analyze lib` — 0 issues.
- `flutter build apk --debug` — успешно.
- APK установлен на телефон.
- Разрешения через `adb pm grant`: FINE, COARSE, BACKGROUND_LOCATION, POST_NOTIFICATIONS.
- `dumpsys package` подтвердил `ACCESS_BACKGROUND_LOCATION: granted=true`.

Следующий тест: активная пробежка при свернутом/заблокированном телефоне. Нужно проверить, виден ли foreground notification и продолжается ли рост маршрута после возврата в приложение.
---

## Ребрендинг на КВАРТАЛ — 2026-06-04 (Сессия 23 — Codex)

Пользователь выбрал название `КВАРТАЛ` и направление логотипа: прозрачный folded-map знак без фона, с исправленной нижней формой.

Ключевые файлы:
- `assets/brand/kvartal-logo-transparent.png` — основной прозрачный PNG логотипа.
- `lib/shared/widgets/kvartal_logo.dart` — общий виджет логотипа и бейджа.
- Android launcher icons обновлены в `android/app/src/main/res/mipmap-*/ic_launcher.png`.

Изменения:
- Видимое название приложения: `КВАРТАЛ` (`AppStrings.appName`, AndroidManifest label, UI-тексты, notifications).
- `assets/brand/` добавлен в `pubspec.yaml`.
- Splash screen полностью заменён на брендированный экран с анимированным логотипом.
- Map top bar, Run header, Start card и центральная Run-кнопка bottom nav используют `KvartalLogoMark/KvartalLogoBadge`.
- Стартовая карточка получила графит/терракота палитру под новый знак.
- Технический package id оставлен `com.kvartal.kvartal_app`, чтобы APK обновлялся поверх установленного приложения.

Проверено:
- `dart analyze lib` — 0 issues.
- `flutter build apk --debug` — успешно.
- APK установлен на телефон и запущен.

Следующее: визуально проверить на телефоне splash, launcher icon, top bar карты, экран тренировки и нижнюю навигацию. Если логотип слишком мелкий/тёмный на launcher icon, пересобрать icon background/scale.
---

## Seamless launch/splash логотипа — 2026-06-04 (Сессия 24 — Codex)

Исправлен стартовый переход приложения `КВАРТАЛ`: native Android launch screen теперь использует тот же фон и тот же логотип, что Flutter splash.

Ключевые файлы:
- `android/app/src/main/res/drawable/launch_logo.png` — native splash logo PNG, сгенерирован из `assets/brand/kvartal-logo-transparent.png`.
- `android/app/src/main/res/drawable/launch_background.xml` и `drawable-v21/launch_background.xml` — чёрный фон + centered launch logo.
- `android/app/src/main/res/values/colors.xml` — `launch_background=#000000`.
- `android/app/src/main/res/values-v31/styles.xml` — Android 12+ splash attrs: `windowSplashScreenBackground`, `windowSplashScreenAnimatedIcon`, `windowSplashScreenIconBackgroundColor`.
- `lib/features/splash/presentation/splash_screen.dart` — Flutter splash переписан так, чтобы первый кадр совпадал с native splash; отдельная rounded-карточка убрана.

Важно:
- Не добавлять обратно `android:postSplashScreenTheme`: сборка падала с `style attribute android:attr/postSplashScreenTheme not found`.
- Для проверки настоящего cold start нужно полностью закрыть приложение на телефоне и открыть с launcher icon, а не только через hot/restart.

Проверено: `dart analyze lib` — 0 issues, `flutter build apk --debug` — успешно, APK установлен и запущен.
---

## Splash/icon fix, удаление demo, локальная история — 2026-06-04 (Сессия 25 — Codex)

Изменения:
- Android adaptive icon добавлен, чтобы убрать белую системную подложку/окантовку при cold start:
  - `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`;
  - `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml`;
  - `android/app/src/main/res/drawable/ic_launcher_background.xml`;
  - `android/app/src/main/res/drawable/ic_launcher_foreground.png`.
- `values-v31/styles.xml`: удалён `android:windowSplashScreenIconBackgroundColor`, потому что он мог давать системную плашку вокруг splash icon.
- `map_screen.dart`: demo-бег полностью удалён. Больше нет `_demo*`, `_toggleDemo`, `_DemoBtn`, `_DemoMarker`, demo polyline/stats.
- Добавлен `completed_runs_provider.dart`: локальная история завершённых пробежек в `SharedPreferences` (`kvartal.completed_runs.v1`).
- `RunNotifier.stop()` сохраняет завершённую пробежку до очистки активного состояния.
- `RunScreen` показывает реальные последние пробежки вместо статического `_recentRuns`.

Проверено:
- `dart analyze lib` — 0 issues.
- `flutter build apk --debug` — успешно.
- APK НЕ установлен на телефон; пользователь сказал установить позже после подключения телефона.

Следующий плановый шаг после проверки на телефоне: серверное хранение пробежек/территорий или отдельный экран полной истории пробежек (`Все`).