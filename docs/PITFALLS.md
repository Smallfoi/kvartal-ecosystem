# PITFALLS — грабли и тупиковые попытки (НЕ повторять)

То, что уже сломалось или не сработало, и как с этим жить. **Перед работой прочитать
целиком.** Нашёл новое — допиши сюда, чтобы второй агент не наступил на те же грабли.

## Окружение / Windows
- **Кириллица в PowerShell бьётся** в `?????`/мусор при записи файлов и heredoc. Решение:
  UTF-8-тексты писать файловым инструментом (Write) или через Python с `encoding='utf-8'`. Не писать кириллицу через PowerShell here-string.
- **PowerShell помечает stderr нативных команд как «ошибку»** (git/gh пишут прогресс в stderr). Это НЕ всегда падение — смотреть фактический результат, а не только «красный» вывод.
- **`/tmp` различается** для git-bash и Windows-python: файл, записанный bash в `/tmp`, Windows-python по `/tmp/...` не находит. Не передавать пути `/tmp` между ними; использовать абсолютные Windows-пути или один интерпретатор.
- **Docker: web перестаёт резолвить host `db`** (`failed to resolve host 'db'`) после нескольких `docker compose restart` — DNS в compose-сети отваливается, хотя сам db healthy. Лечится `docker compose up -d --force-recreate web` (просто restart не помогает). GitHub API/git тоже периодически моргают (EOF/SSL handshake) — повторять с ретраями.

## CI / branch protection
- **Переименование CI-джобы, которая в required status checks, блокирует мерж.** Имя job (`name:` в ci.yml) = контекст в ruleset `protect-main`. Если поменять имя (напр. `Backend · FastAPI`→`Backend · Django`), старый контекст в required больше не появится → PR висит «Expected». Решение: синхронно обновить контексты в ruleset через `gh api -X PUT repos/<owner>/<repo>/rulesets/<id> --input body.json` (тело с `rules[].required_status_checks` писать ФАЙЛОМ — там «·» не-ASCII, PowerShell бьёт). ID правила: `gh api .../rulesets`.

## Backend (FastAPI dev)
- **Бек часто падает / его убивают** (фоновый процесс умирает, exit 4/127). Симптомы в приложении:
  `DioException`, `Connection closed before full header`, `Connection refused`. ПЕРВЫМ делом проверить
  `GET /v1/health` и при необходимости перезапустить: `cd backend && PYTHONUNBUFFERED=1 python -m uvicorn main:app --host 0.0.0.0 --port 8000`.
- **Не диагностировать «обрыв соединения» как баг клиента, пока не проверил, что бек жив.** Однажды это был
  именно упавший бек, а не код.
- Логи uvicorn в файл **буферизуются** — запускать с `PYTHONUNBUFFERED=1`, иначе свежих строк не видно.

## Телефон / устройство
- **Dev-бек доступен телефону только по USB** (`adb reverse tcp:8000 tcp:8000`) или по Wi-Fi (а там фаервол Windows).
  На улице связи НЕТ → начисления должны идти через офлайн-очередь, иначе теряются.
- **Тест «пробежка → баллы» требует реального движения по GPS.** Стоящий телефон = 0 км = 0 баллов
  (пробежка с `route.length<=1` даже не сохраняется). Мок-локаций на физическом устройстве нет из коробки.
- Кнопка СОХРАНИТЬ/нижняя навигация близко — при тапах через `adb input` легко промахнуться (мерить по координатам).
- Очистка текстового поля через `adb`: `KEYCODE_MOVE_END` не работает на этой клавиатуре; чистить `tap + N×KEYCODE_DEL(67) + N×KEYCODE_FORWARD_DEL(112)`.
- Скриншоты: устройство 1224×2720; ресайз до 600 шириной (scale ≈2.04). Чёрный кадр = погас экран (`input keyevent KEYCODE_WAKEUP`).

## Flutter / CI
- **Пустые asset-папки в `pubspec.yaml` ломают `flutter analyze` в CI** (`asset_directory_does_not_exist`):
  git не хранит пустые папки. Решение: `.gitkeep` в каждую объявленную, но пустую папку. Локально не воспроизводится (папки физически есть).
- **`pubspec.lock` коммитим** (приложения, не пакеты) — чтобы CI ставил те же версии, что локально.
- CI пинит **Flutter 3.32.1** — держать локально ту же версию, иначе analyze может расходиться.

## Dio / сеть (Квартал)
- **Dio + keep-alive поверх `adb reverse`** даёт `Connection closed before full header`, когда uvicorn закрывает idle keep-alive.
  Смягчение: заголовок `Connection: close` на запросах лояльности + не слать дубль-запросы разом. (Но чаще причина — упавший бек, см. выше.)

## GitHub
- **Branch protection / rulesets на ПРИВАТНОМ репо бесплатного плана = HTTP 403** («Upgrade to Pro or make public»).
  Решение для этого проекта: репозиторий сделан публичным (см. DECISIONS D-05).
- `gh` не в PATH текущих сессий после установки — звать по полному пути `C:\Program Files\GitHub CLI\gh.exe`.
- Имена обязательных CI-проверок (с «·»): `Flutter · kvartal-app`, `Flutter · sport_store`, `Backend · FastAPI`.
