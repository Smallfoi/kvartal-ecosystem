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


## 2026-06-20 — Claude — Admin v2, Фаза 1: django-unfold (красивая тема + структура)
**Контекст:** ресёрч по админкам лидеров (Shopify/Stripe/Linear/Storyblok/Sanity/django-unfold). Решили взять лучшее: unfold-тема + структура (Фаза 1), затем Draft/Publish (2), live-preview сайта в iframe (3), live-preview приложения через Flutter Web (4). Выбор владельца по превью аппа — Flutter Web (пиксель-точно).
**Сделано (Фаза 1):**
- `django-unfold` в requirements; в INSTALLED_APPS перед `django.contrib.admin` (+ `unfold.contrib.filters/forms`).
- `UNFOLD` в settings: брендовый primary = electric blue (#0A84FF), боковое меню с группами **Каталог / Магазин / Сообщество** (иконки Material Symbols), поиск в сайдбаре, тёмная тема.
- Все ModelAdmin переведены на `unfold.admin.ModelAdmin`; стандартные `User`/`Group` перерегистрированы под тему.
**Проверено вживую:** rebuild с unfold, `manage.py check` чисто; вход в админку 200 (тема `unfold` в HTML), список товаров 200; на устройстве — экран входа в новой тёмной теме с акцентом STAW Admin (electric blue), кнопка «Войти →».
**Дальше:** Фаза 1b — дашборд с KPI (заказы/выручка/баллы/пользователи) и графиками; затем Draft/Publish и live-preview.

## 2026-06-20 — Claude — Admin-панель (Django admin) — владелец сам управляет каталогом/заказами/клубами/баллами
**Сделано:** подключил Django-админку `/admin/` для управления данными экосистемы без кода.
- `admin.py` во всех приложениях: catalog (Category/Product/Banner), orders (Order — статус правится прямо в списке), shoes (ShoeAsset), loyalty (LoyaltyTransaction), clubs (Club/ClubMember/ClubJoinRequest), accounts (Account). Удобные list_display/filter/search, превью фото.
- **Загрузка фото товаров:** добавил `Product.image` (ImageField, миграция 0002), Pillow в requirements, отдельный записываемый том `media_uploads:/srv/media/uploads`. Загруженное фото отдаётся по сети `/media/uploads/products/…` и приоритетнее старых бандл-ассетов; `Product.to_json` теперь отдаёт `imageUrl` (сетевой), трекер кроссовок Квартала берёт это фото.
- Брендинг админки (site_header «STAW — администрирование экосистемы»).
- Суперюзер для dev создаётся `createsuperuser --noinput` с env `DJANGO_SUPERUSER_USERNAME/PASSWORD/EMAIL` (креды НЕ коммитим; dev: admin / staw-admin-2026).
**Проверено вживую:** rebuild с Pillow, миграция применена; вход в админку ОК; списки product/orders/accounts/clubs/shoes/loyalty отдаются 200; загрузка фото → файл в томе + отдаётся по сети 200. Тестовое фото убрал.
**Дальше:** при желании — модерация/роли в админке, экспорт; либо следующее из аудита (пуш-уведомления, оплата/SMS, Redis-Celery).

## 2026-06-20 — Claude — Shoes: удаление пары (корзина) + редизайн попапа (анимация, кнопки по центру)
**Сделано:** по правкам владельца — добавил удаление кроссовок и причесал всплывающее окно.
- **Удаление:** бэк `DELETE /v1/shoes/<id>` (`shoe_delete`); провайдер `delete(shoeId)`; на карточке трекера — иконка-корзина (`CupertinoIcons.trash`) → диалог «Удалить кроссовки? Убрать «model» из приложения?» (Отмена/Удалить) → удаление + refresh.
- **Попап красивее:** `showAddShoeDialog` переведён на `showGeneralDialog` с анимацией появления (scale 0.9→1.0 `easeOutBack` + fade, 240мс). Компактная карточка (фото 88, subtle-бордюр), кнопки «Нет»/«Да» — маленькие пилюли (StadiumBorder, 100×42) **по центру**, минималистичные, правильные пропорции.
**Проверено на устройстве:** попап всплывает на карте при открытии с новым видом (фото + центрированные пилюли); «Да» → пара в трекере с иконкой-корзиной; корзина → диалог → «Удалить» → `DELETE 200` → пустой трекер. API: confirm→active→DELETE 200, missing→404. analyze чисто, demo убран.

## 2026-06-19 — Claude — Shoes: попап про новые кроссовки — при открытии приложения + вопрос «Да/Нет» (уточнение замечания №1)
**Сделано:** по просьбе владельца — спрашивать про покупку не на экране кроссовок, а **сразу при открытии приложения**, и вопрос проще: «Добавить кроссовки в приложение?» Да/Нет (без «Не для бега»).
- Вынес попап в общий помощник `features/shoes/presentation/shoe_prompt.dart` (`promptPendingShoes` + `showAddShoeDialog`, кнопки **Нет/Да**, текст «Добавить эти кроссовки в приложение?», с фото).
- `MainScaffold` → ConsumerStatefulWidget: при открытии приложения, как только подгрузились `pending` кроссовки, всплывает окно (глобально, на любом табе; один раз за запуск; `ref.listen` ловит догрузку после первого кадра).
- Экран «Мои кроссовки» больше сам не вызывает попап (только обновляет список); инлайн-карточки «Новые покупки» теперь с кнопками **Да/Нет**.
**Проверено:** analyze чисто; release APK собрался. На устройстве доснять не удалось (телефон отключился по USB) — логика стандартная (ref.listen + showDialog в шелле), сам диалог+фото уже подтверждены на устройстве в прошлой итерации. Владелец проверит: купить кроссовки → открыть приложение → сразу всплывает «Добавить кроссовки? Да/Нет».

## 2026-06-19 — Claude — Клуб: вступление по скану QR (замечание владельца №2)
**Сделано:** в Квартале можно вступить в клуб, отсканировав QR-код приглашения штатной камерой (как в Тинькофф/Taobao).
- Пакет `mobile_scanner ^7.2.0`; в манифест добавил `CAMERA`-permission; minSdk поднят до 23 (требование mobile_scanner) — `minSdk = maxOf(flutter.minSdkVersion, 23)`.
- Новый `club_scan_screen.dart`: полноэкранный сканер (камера + синяя рамка-видоискатель + назад/фонарик + подсказка). По QR → `joinByInvite(raw)` (уже существующий разбор кода/ссылки `https://kvartal.app/club/<id>`) → возврат назад, результат снекбаром. Игнорит «не-приглашения», `noDuplicates`.
- Маршрут `/club/scan` — top-level (вне шелла), полноэкранный.
- Кнопки скана: отдельная иконка в углу шапки клуба (видна вне клуба) + кнопка «Скан QR» рядом с «Вступить» в карточке приглашения.
**Проверено:** analyze чисто; release APK собрался (45.8 МБ — ML Kit в комплекте); на устройстве — кнопки видны, сканер открывается, камера работает (live), рамка/назад/фонарик/подсказка на месте, без крэшей. Реальный скан QR→join — за владельцем (нужен физический QR); сам join-путь (`joinByInvite`) уже работал для ручного ввода кода.
**Прим.:** APK вырос из-за бандла ML Kit; при желании позже можно перейти на unbundled-модель Google Play Services.

## 2026-06-19 — Claude — Shoes: подтверждение перед добавлением + реальные фото (замечание владельца №1)
**Сделано:** кроссовки теперь НЕ добавляются в трекер автоматически — спрашиваем пользователя (мог купить в подарок / не для бега), и показываем реальное фото.
- Бэк: `ShoeAsset.status` (pending/active/declined, миграция 0003). Покупка → `pending`. `GET /v1/shoes` отдаёт только active (трекер), новый `GET /v1/shoes/pending` — ждущие решения, `POST /v1/shoes/<id>/confirm {add}` → active или declined. `distance` только на active (иначе 409).
- Фото: бэк отдаёт картинки товаров по сети — `/media/products/<file>` (в dev примонтировал папку `sport_store/assets/images/products` в web-контейнер; settings MEDIA_*; static-раздача в urls). `create_for_order` пишет `image_url=/media/...`. Прод — реальный CDN.
- Квартал `shoes_provider`: `pending` + `confirm(add)` + `resolveShoeImageUrl` (относительный путь → абсолютный из baseUrl). `shoes_screen`: всплывающее окно «Добавить в трекер?» с фото при открытии + секция «Новые покупки» с карточками (фото + «Не для бега»/«Добавить»). Профиль: карточка «N новых пар — подтвердите».
**Проверено:** API — pending→confirm(add→active / decline→declined), distance на active=15км, на declined=409, `/media/...jpg` отдаётся 200 (32КБ). На устройстве — всплывающее окно с реальным красным фото Air Runner X1 + кнопки; инлайн-карточка pending с фото; `GET /shoes`+`/shoes/pending`+`/media` сыпались с телефона. analyze kvartal чисто. (Финальный тап «Добавить» на устройстве не доснял — телефон отключился; путь confirm проверен по API.)
**Дальше (замечание №2):** вступление в клуб по скану QR (отдельная кнопка-сканер как в Тинькофф/Taobao → штатная камера → QR → вступление).

## 2026-06-19 — Claude — Shoes: UI трекера в Квартале + начисление км после пробежки (связка завершена)
**Сделано:** app-сторона Shoes — Квартал показывает кроссовки и убавляет их ресурс пробежками.
- Бэк: `POST /v1/shoes/<id>/distance` теперь идемпотентен по `runId` (поле `ShoeAsset.applied_runs`, миграция 0002) — офлайн-очередь Квартала может переслать пробежку повторно без задвоения км.
- Квартал `features/shoes/`: `shoes_provider.dart` (модель ShoeAsset + ShoesNotifier; `GET /shoes`, офлайн-очередь начислений как у loyalty, `applyRunDistance(km, runId)` на активную пару), `shoes_screen.dart` (экран «Мои кроссовки»: карточки с прогресс-баром износа, остаток км, бейдж «Заменить», пустое состояние).
- Профиль: карточка «Кроссовки» (остаток активной пары / CTA) → `/profile/shoes` (shell-route, таб-бар не залипает — правило про повтор багов соблюдено). Рефреш кроссовок при открытии профиля + pull-to-refresh.
- Пробежка завершена → `run_provider._applyShoeWear(run)` списывает км с активной пары (идемпотентно по runId, офлайн долетит позже).
**Проверено на устройстве (разбуж. экран):** профиль рисует карточку «Кроссовки» (пусто→«купи в STAW», `GET /shoes` 200); сид демо-пары через API → экран «Мои кроссовки» показал Air Runner X1, «Осталось 420 из 600 км», 30%, синий бар; таб-бар активен. analyze kvartal чисто, demo-данные удалены.
**Дальше:** Shoes полностью замкнут (Store покупка → Квартал трекер → пробег убавляет). Остаются по аудиту: Admin-панель, реальная оплата/SMS, Redis/Celery, очистка старых блок-зон территорий.

## 2026-06-19 — Claude — Shoes: трекер износа кроссовок (бэк) — флагманская связка Store↔Квартал
**Сделано:** реализовал `ShoeAsset` (ECOSYSTEM_API §2.5/§4.3, идея из IDEAS.md) — купил кроссовки → ресурс износа; Квартал убавляет километраж.
- Новое приложение `backend/django_api/shoes/`: модель `ShoeAsset` (user_id, product_id, order_id, model, image_url, total_km, max_km=600, retired; db_table `store_shoes`; idемпотентность по (user, order, product); to_json с `remainingKm`/`wearPercent` для UI).
- Эндпоинты: `GET /v1/shoes` (кроссовки пользователя), `POST /v1/shoes/<id>/distance {km}` (добавить пробег, авто-`retired` при ≥ max_km).
- **Серверное авто-создание**: `POST /v1/orders` → для каждой обуви (категория `shoes`) заводит `ShoeAsset` (через `shoes.views.create_for_order`, идемпотентно, обёрнуто в try — заказ важнее). Store менять не пришлось.
- Зарегистрировал app в settings, маршруты в config/urls, миграция `0001`.
- Обновил `MODULES.md` (он устарел — привёл статусы к реальности: каталог/заказы ✅, территории/рейтинг/сайт/инфра 🟡, Shoes 🟡) и `ECOSYSTEM_API.md` §6 (Shoes backend done).
**Проверено вживую :8000:** логин → заказ с кроссовками (200) → `GET /shoes` создан ресурс (0/600) → +120км (remaining 480, wear 20%) → +500км (retired=True) → повторный заказ не задвоил (1 ресурс) → distance на чужой id = 404. Тестовые данные за Михаила удалил. `manage.py check` чисто, миграция применена.
**Дальше:** UI трекера в Квартале (`GET /shoes` карточка + начисление км после пробежки `POST /shoes/:id/distance`). Затем — реальная оплата/SMS/Admin-панель/Redis-Celery (см. аудит остатков).

## 2026-06-18 — Claude — Прод-конфиг API (env/флаги, dev-дефолты не трогаем) [D-15]
**Сделано:** подготовил переключение dev↔prod без правок кода (хостинга ещё нет — домены подставит владелец).
- **Backend** `settings.py`: `ALLOWED_HOSTS` и CORS теперь из env. `DJANGO_ALLOWED_HOSTS` (дефолт `*`), `DJANGO_CORS_ORIGINS` (пуста→CORS открыт для dev; задана→только эти + `CSRF_TRUSTED_ORIGINS`). Добавил `SECURE_PROXY_SSL_HEADER` (за HTTPS-прокси). `SECRET_KEY`/`DEBUG` уже были из env.
- **Приложения:** база API уже через `--dart-define` (`SPORT_STORE_API_BASE_URL`, `KVARTAL_API_BASE_URL`). Последний хардкод-URL (`zone_provider.dart`, zones-сервис :3000) перевёл в `String.fromEnvironment('KVARTAL_ZONES_URL', …)` с тем же дефолтом.
- **Сайт** `ecosystem.js`: API-база авто — `localhost`→dev `:8000`, иначе `PROD_API` (плейсхолдер `https://api.staw.ru/v1`) или `window.STAW_API_BASE`.
- **Доки:** новый `docs/DEPLOY.md` (чеклист деплоя), обновил `.env.example` (прод-блок), `DECISIONS.md` D-15.
**Проверено:** backend перезапущен — health ok, CORS в dev по-прежнему `*`; `node --check ecosystem.js` ok; `flutter analyze` kvartal чисто. Dev-поведение не изменилось.
**Дальше:** при появлении хостинга — завести домены, выставить env/флаги по `docs/DEPLOY.md`, заменить `PROD_API`. Затем «красота» — за владельцем.

## 2026-06-18 — Claude — Экономика: идемпотентное начисление за покупку (финал Store-на-бэке)
**Сделано:** закрыл последний пробел экономики — начисление баллов за покупку теперь идемпотентно по заказу (как и трата).
- Бэк `/v1/loyalty/transactions`: добавил дедуп по `(user, orderId, source)` (раньше только по `(user, runId, source)`). Повторный пост того же заказа не дублирует баллы.
- Клиент: `earnForPurchase(..., orderId)` передаёт `order.id` в начисления (purchase + бонус за первый заказ); чекаут прокидывает `order.id`.
**Проверено вживую :8000:** earn +50 один раз, повторы того же orderId → `deduped` (баланс 131→181, не +150). analyze+test зелёные, release на разбуженном устройстве грузит каталог.
**ИТОГ:** экономика экосистемы целостна — и трата (redeem), и начисление (earn) серверно-идемпотентны и привязаны к заказу/забегу. Store-на-бэке полностью завершён.
**Остаётся (не блокеры):** прод-конфиг API (https/домен) при появлении хостинга; «красота» сайта/приложений — за владельцем.

## 2026-06-18 — Claude — Store: кросс-девайс история заказов + грабля «спящий экран»
**Сделано:** `OrderProvider` синхронизирует историю заказов с бэком (как `LoyaltyProvider`).
- `OrderProvider(serverBacked)` + `syncAuth(loggedIn)` → при логине `refresh()` тянет `GET /v1/orders` и сливает с локальными (у локальных приоритет — живые статусы текущей сессии, серверные добавляются как история). main.dart: `ChangeNotifierProxyProvider2<AuthProvider, NotificationsProvider, OrderProvider>` (serverBacked=useApiOrder, syncAuth по auth).
**Грабля (важно, в памяти reference-android-device-testing):** долго ловил «чёрный экран / нет запросов» на устройстве — оказалось **экран был Dozing** (Flutter на спящем экране не рендерит и не шлёт запросы → ложная тревога, НЕ баг). Перед проверкой будить: `input keyevent KEYCODE_WAKEUP` + `wm dismiss-keyguard`, проверять `dumpsys power | grep mWakefulness=Awake`.
**Проверено:** /orders POST/GET (раньше), analyze+test зелёные, release на разбуженном устройстве рендерит + грузит каталог (200). История заказов с сервера подтянется после логина (auth-gated) — визуально за владельцем.

## 2026-06-18 — Claude — Сайт STAW подключён к экосистеме (D-13, последняя поверхность)
**Сделано:** статический сайт `САЙТ STAW/` подключён к общему аккаунту + баллам.
- Новый самодостаточный модуль `ecosystem.js`: сам инжектит виджет в шапку + свои стили (классы `.eco-*`) + всю логику. Вход по телефону (`POST /v1/auth/phone/verify`, dev-код 1234) → JWT в localStorage → показывает имя + общий баланс баллов (`GET /v1/loyalty/account`), кнопка «Выйти». Дизайн сайта (index/styles/script) НЕ трогал — только 1 строка `<script src="ecosystem.js">` в index.html. Владелец наведёт красоту позже, виджет легко перенести/перестилизовать.
- CORS на бэке уже открыт (`CORS_ALLOW_ALL_ORIGINS`), Authorization-заголовок разрешён — браузер ходит в API.
**Проверено:** node --check ecosystem.js OK; CORS preflight /loyalty/account → 200 (allow-origin *, allow authorization); auth/phone/verify с Origin браузера → token+user; сайт отдаётся `python -m http.server` и подключает ecosystem.js (200). Визуальный клик-через — за владельцем (открыть сайт по http, не file://).
**Как запустить (dev):** backend `cd backend && docker compose up -d`; сайт `cd "САЙТ STAW" && python -m http.server 5577` → открыть http://localhost:5577 (на том же ПК, где backend на :8000). Не открывать как file:// (браузер заблокирует запросы).
**ИТОГ:** все 3 поверхности D-13 на общем бэке — Квартал, SportStore, Сайт STAW (единый аккаунт + общие баллы).
**Дальше:** прод-конфиг API (https/домен вместо 127.0.0.1) для сайта; (опц.) корзина/заказы сайта на бэке; полировка/«красота» — за владельцем.

## 2026-06-18 — Claude — Store на бэке: заказы (D-13)
**Сделано:** заказы SportStore сохраняются на Django.
- Новый app `orders` (Order: user_id, order_id, total, status, points_redeemed, payload JSON; миграция 0001; unique (user_id, order_id) — идемпотентность). `POST /v1/orders` (Bearer) сохраняет заказ пользователя и возвращает его; `GET /v1/orders` — заказы пользователя (новые сверху). Контракт payload = как у SportStore Order.toJson/fromJson.
- Клиент: `useApiOrder=true` (ApiOrderRepository уже был готов; `OrderProvider.placeOrder` шлёт `submitOrder` на бэк — заказ персистится на сервере).
**Проверено вживую :8000:** POST заказа → 200 (возвращает полный заказ), повтор того же id → идемпотентно (1 в списке), GET → список, без токена → 401. Release-сборка на устройстве грузит каталог (сеть ок). analyze+test зелёные.
**Прим.:** показ истории в приложении пока локальный (live-таймеры статусов в OrderProvider); серверный список (`fetchOrders`) готов для кросс-девайс синка — подключим при необходимости. Начисление за покупку уже идёт на сервер через `/loyalty/transactions`.
**Дальше по D-13:** (опц.) кросс-девайс синк заказов/статусов + идемпотентное начисление за покупку через сервер; затем сайт STAW.

## 2026-06-18 — Claude — РЕШЕНО: SportStore release не имел INTERNET-permission
**Корень найден:** в main-манифесте SportStore НЕ было `android.permission.INTERNET`. Flutter добавляет INTERNET сам только в debug/profile-манифест, в release — нет. Поэтому RELEASE-сборка вообще не имела доступа к сети (пустой каталог; ломались ВСЕ API Store: auth/loyalty/catalog). Квартал работал, т.к. в его main-манифесте INTERNET есть (это была НЕ разница package:http vs dio).
**Фикс:** добавил `<uses-permission android:name="android.permission.INTERNET"/>` в main-манифест SportStore.
**Проверено на устройстве:** RELEASE-сборка тянет каталог с бэка — categories/products/banners/brands/sizes/price-range → 200. Каталог отображается. Релиз рабочий (без debug-ленты).
**Итог:** Store-на-бэке (каталог + трата баллов) полностью работает в release на устройстве.
**Дальше по D-13:** заказы Store на бэке + начисление за покупку через сервер; затем сайт STAW.

## 2026-06-18 — Claude — SportStore: cleartext в release + находка про release-сеть
**Контекст:** владелец: «каталог пустой» на устройстве после включения API-каталога.
**Найдено (adb + screenshot + сравнение debug/release):**
- В release HTTP по `http://` блокировался: cleartext был только в `debug/AndroidManifest`. Добавил `usesCleartextTraffic="true"` в main-манифест SportStore; заодно `EnableImpeller=false` (как в Квартале — на Mediatek/Infinix release падал/глючил).
- **DEBUG-сборка SportStore работает**: устройство тянет каталог с бэка (categories/products/banners/brands/sizes/price-range → 200), товары/категории отображаются.
- **RELEASE-сборка SportStore НЕ шлёт запросы** на этом устройстве (процесс жив, foreground, cleartext в APK подтверждён, Impeller off — не помогло). Квартал (release, dio) сеть работает; SportStore использует `package:http` — вероятно, в этом разница. Затрагивает ВСЕ API-фичи Store (auth/loyalty/catalog), не только каталог. **Не дорешено.**
**Сейчас:** на устройство поставлена рабочая DEBUG-сборка SportStore (каталог грузится). Релизную сеть добиваем отдельно.
**Дальше:** разобраться с release-networking SportStore (package:http vs dio / возможно сетевой клиент); потом заказы Store на бэке.

## 2026-06-18 — Claude — Store на бэке: каталог (D-13)
**Сделано:** каталог SportStore переехал с mock на Django.
- Новый app `catalog` (Category/Product/Banner, JSONField для списков; миграция 0001). Сид `seed_catalog` = 1:1 с прежним mock_data.dart (7 категорий / 16 товаров / 3 баннера; картинки — бандл-ассеты приложения, бэк отдаёт пути).
- Эндпоинты (публичные, контракт как у `ApiProductRepository`): `GET /v1/categories`, `/v1/products` (+category,featured,new), `/v1/products/search?q=`, `/v1/products/price-range`, `/v1/products/<id>`, `/v1/brands`, `/v1/sizes`, `/v1/banners`. Порядок в urls: search/price-range раньше `<pid>`.
- Клиент: `useApiCatalog=true` (репозиторий ApiProductRepository уже был готов под эти эндпоинты — экраны не трогал).
**Проверено вживую :8000:** categories 7, products 16 (camelCase ключи), category=shoes 3, featured 7, new 7, search «куртка» 3, price-range 1490..16990, /products/3 ок, /999 404, brands 4, sizes, banners 3. analyze+test sport_store зелёные, собрал+поставил.
**Прим.:** на устройстве визуальное подтверждение за владельцем (Infinix агрессивно переключал фокус приложений при моих скриптовых запусках; механизм 127.0.0.1+adb reverse тот же, что у Квартала — он на устройстве подтверждён).
**Дальше по D-13:** заказы Store на бэке (useApiOrder); начисление за покупку через сервер; затем сайт.

## 2026-06-18 — Claude — Store на бэке: трата баллов (D-13) — серверный redeem
**Сделано (замкнули петлю «заработал бегом → потратил в магазине»):**
- **Бэк** `POST /v1/loyalty/redeem` {amount, orderId, description}: авторитетно проверяет баланс (нельзя в минус), идемпотентен по orderId+source=redeem (нет двойного списания), пишет −amount source=redeem, возвращает новый balance/level.
- **SportStore:** `LoyaltyRepository.redeem()` (Api → /loyalty/redeem), `LoyaltyProvider.redeem` стал async server-authoritative (serverBacked: списывает на сервере → `load()` перечитывает реальный баланс; ошибку «Недостаточно баллов» возвращает текстом; офлайн-прототип — как было локально). Чекаут `_confirm` ждёт redeem и показывает ошибку в SnackBar.
**Проверено вживую :8000:** redeem 30 (161→131), повтор того же заказа → deduped (без двойного списания), 999999 → 400 «Недостаточно баллов», 0 → 400. analyze+test sport_store зелёные.
**Дальше по D-13:** каталог + заказы Store на бэке; начисление за покупку через сервер (сейчас earn идёт через generic /loyalty/transactions).

## 2026-06-18 — Claude — фикс залипания: экран доступа к геолокации → маршрут шелла
**Контекст:** владелец заметил, что экран «фоновой работы» (настройка геолокации на экране Бег) залипает — открыт как `showModalBottomSheet`, и таб-бар не переключает экраны. Та же ошибка, что чинили у истории баллов/редактирования профиля/настроек.
**Сделано:** `location_setup_sheet.dart` → `LocationSetupScreen` (Scaffold) + маршрут `/run/location-access` внутри ShellRoute; `openLocationSetup(context)=context.push(...)`, закрытие `context.pop()`. Баннер и авто-онбординг зовут `openLocationSetup`. Теперь таб-бар переключает.
**Фидбэк владельца (важно, в память [[feedback-no-repeat-fixed-bugs]]):** не повторять уже исправленные баги в новых экранах. Правило: детальные/оверлейные экраны под таб-баром = ВСЕГДА маршрут в ShellRoute (`context.push`), не `Navigator.push`/`showModalBottomSheet`.
**Проверено:** analyze зелёный, собрал и поставил на устройство.

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
