# PITFALLS — грабли и тупиковые попытки (НЕ повторять)

То, что уже сломалось или не сработало, и как с этим жить. **Перед работой прочитать
целиком.** Нашёл новое — допиши сюда, чтобы второй агент не наступил на те же грабли.

## Flutter сборка/установка на устройство (ВАЖНО — стоило доверия владельца)
- **Инкрементальная `flutter build apk` может отдать СТАРЫЙ скомпилированный код** части экранов после серии правок/мержей/`git pull` (mtime/кэш kernel). APK получается «винегретом»: одни экраны новые, другие старые. CI при этом зелёный (CI собирает с нуля). **Перед сборкой на телефон ВСЕГДА `flutter clean` + `flutter pub get` + build.** Это решает.
- **`adb install -r` НЕ перезапускает уже открытое приложение** — старый процесс крутится дальше, кажется «ничего не установилось». После установки: `adb shell am force-stop <pkg>` + перезапуск (а лучше — полное `adb uninstall`+install при сомнениях).
- **Скрин-проверка фиксов — ОБЯЗАТЕЛЬНО прокручивать экран до конца** (не только верх): убранный/добавленный блок может быть внизу. Скрин только верха ввёл и меня, и владельца в заблуждение.

## Прод-деплой (найдено на dry-run прод-стека)
- **`SECURE_SSL_REDIRECT=True` (DEBUG=0) форсит HTTP→HTTPS.** Прямой запрос к gunicorn (smoke-тест, healthcheck, отладка) БЕЗ заголовка `X-Forwarded-Proto: https` получает 301 на `https://…` и падает (`SSL: WRONG_VERSION_NUMBER`, т.к. gunicorn слушает plain HTTP). Через nginx всё ок (он шлёт этот заголовок). Решение: в прямых проверках слать `X-Forwarded-Proto: https` (так и сделано в `deploy/smoke.sh`) или ходить через nginx.
- **Dry-run прод-стека ОКУПАЕТСЯ:** `docker compose -p stawdry -f docker-compose.prod.yml --env-file .env up -d db redis web` (изолированный проект, без nginx, со своим `.env`) ловит проблемы прод-конфига до реального хостинга. Так и нашли пункт выше.

## Окружение / Windows
- **Кириллица в PowerShell бьётся** в `?????`/мусор при записи файлов и heredoc. Решение:
  UTF-8-тексты писать файловым инструментом (Write) или через Python с `encoding='utf-8'`. Не писать кириллицу через PowerShell here-string.
- **PowerShell помечает stderr нативных команд как «ошибку»** (git/gh пишут прогресс в stderr). Это НЕ всегда падение — смотреть фактический результат, а не только «красный» вывод.
- **`/tmp` различается** для git-bash и Windows-python: файл, записанный bash в `/tmp`, Windows-python по `/tmp/...` не находит. Не передавать пути `/tmp` между ними; использовать абсолютные Windows-пути или один интерпретатор.
- **`curl -d '{...кириллица...}'` в git-bash бьёт UTF-8** — тело уходит мусором, запрос молча падает (юзер не создаётся, токен пустой). Для API-проверок с кириллицей использовать Django **test Client** (UTF-8 гарантирован) или `curl --data @файл`.
- **`docker compose exec ... /tmp/x.py` — MSYS конвертит `/tmp` в win-путь** (`C:/Users/.../Temp/x.py`) → «No such file». Ставить `MSYS_NO_PATHCONV=1` перед командой. И скрипт для Django класть в **`/app`** (а не `/tmp`): python добавляет в `sys.path` каталог скрипта, а `config` лежит в `/app` → иначе `ModuleNotFoundError: config`.
- **Docker: web перестаёт резолвить host `db`** (`failed to resolve host 'db'`) после нескольких `docker compose restart` — DNS в compose-сети отваливается, хотя сам db healthy. Лечится `docker compose up -d --force-recreate web` (просто restart не помогает). GitHub API/git тоже периодически моргают (EOF/SSL handshake) — повторять с ретраями.

## CI / branch protection
- **Переименование CI-джобы, которая в required status checks, блокирует мерж.** Имя job (`name:` в ci.yml) = контекст в ruleset `protect-main`. Если поменять имя (напр. `Backend · FastAPI`→`Backend · Django`), старый контекст в required больше не появится → PR висит «Expected». Решение: синхронно обновить контексты в ruleset через `gh api -X PUT repos/<owner>/<repo>/rulesets/<id> --input body.json` (тело с `rules[].required_status_checks` писать ФАЙЛОМ — там «·» не-ASCII, PowerShell бьёт). ID правила: `gh api .../rulesets`.

## Backend (Django + Docker, dev)
- **Docker Desktop в dev иногда сам останавливается** (`failed to connect to the docker API ... pipe`),
  и тогда бек на :8000 недоступен. Симптомы в приложении: `DioException`, `Connection closed before full
  header`, `Connection refused`, «нет товаров»/пустые экраны. ПЕРВЫМ делом проверить `GET /v1/health`;
  если бек лежит — запустить Docker Desktop и `cd backend && docker compose up -d`.
- **Не диагностировать «обрыв соединения»/«нет данных» как баг клиента, пока не проверил, что бек жив.**
  Не раз это был упавший Docker/бек, а не код приложения.
- Логи бэка: `cd backend && docker compose logs web` (свежие — `--since 30s`); `docker compose exec`
  запускать ТОЛЬКО из папки `backend/` (иначе `no configuration file provided: not found`).

## Телефон / устройство
- **Dev-бек доступен телефону только по USB** (`adb reverse tcp:8000 tcp:8000`) или по Wi-Fi (а там фаервол Windows).
  На улице связи НЕТ → начисления должны идти через офлайн-очередь, иначе теряются.
- **Тест «пробежка → баллы» требует реального движения по GPS.** Стоящий телефон = 0 км = 0 баллов
  (пробежка с `route.length<=1` даже не сохраняется). Мок-локаций на физическом устройстве нет из коробки.
- Кнопка СОХРАНИТЬ/нижняя навигация близко — при тапах через `adb input` легко промахнуться (мерить по координатам).
- Очистка текстового поля через `adb`: `KEYCODE_MOVE_END` не работает на этой клавиатуре; чистить `tap + N×KEYCODE_DEL(67) + N×KEYCODE_FORWARD_DEL(112)`.
- Скриншоты: устройство 1224×2720; ресайз до 600 шириной (scale ≈2.04). Чёрный кадр = погас экран (`input keyevent KEYCODE_WAKEUP`).

## Flutter ↔ backend (профиль / аватар)
- **Загрузка аватара через пакет `http` (`MultipartFile.fromPath`) шлёт `application/octet-stream`** —
  он НЕ определяет MIME по расширению. Backend проверяет `content_type.startswith("image/")` и
  отклоняет 400 «Нужен файл-изображение» → в UI «не получается сменить фото», молча. Решение: явно
  задавать `contentType: MediaType('image', …)` (пакет `http_parser`) по расширению файла. У Dio
  (Квартал) проблемы нет — `MultipartFile.fromFile` ставит MIME сам, поэтому там аватар работал.
- **GoRouter `refreshListenable` поверх auth-провайдера — рефрешить ТОЛЬКО по смене статуса входа.**
  Если дёргать `notifyListeners()` на каждое изменение auth-состояния (поля профиля, аватар,
  isLoading), то при «Сохранить» весь стек роутера пересобирается → экран редактирования мелькает и
  проблёскивает предыдущий экран. Гейт: `if (prev?.status != next.status) notifyListeners();`.

## Flutter / CI
- **Пустые asset-папки в `pubspec.yaml` ломают `flutter analyze` в CI** (`asset_directory_does_not_exist`):
  git не хранит пустые папки. Решение: `.gitkeep` в каждую объявленную, но пустую папку. Локально не воспроизводится (папки физически есть).
- **`pubspec.lock` коммитим** (приложения, не пакеты) — чтобы CI ставил те же версии, что локально.
- CI пинит **Flutter 3.32.1** — держать локально ту же версию, иначе analyze может расходиться.

## Dio / сеть (Квартал)
- **Dio + keep-alive поверх `adb reverse`** даёт `Connection closed before full header`, когда dev-сервер закрывает idle keep-alive.
  Смягчение: заголовок `Connection: close` на запросах лояльности + не слать дубль-запросы разом. (Но чаще причина — упавший бек, см. выше.)

## GitHub
- **Branch protection / rulesets на ПРИВАТНОМ репо бесплатного плана = HTTP 403** («Upgrade to Pro or make public»).
  Решение для этого проекта: репозиторий сделан публичным (см. DECISIONS D-05).
- `gh` не в PATH текущих сессий после установки — звать по полному пути `C:\Program Files\GitHub CLI\gh.exe`.
- Имена обязательных CI-проверок (с «·»): `Flutter · kvartal-app`, `Flutter · sport_store`, `Backend · Django`.
