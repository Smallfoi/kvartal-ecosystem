# SportStore — состояние проекта

Flutter-приложение спортивного магазина. Дизайн: черно-белый, минималистичный, спортивный премиальный стиль. Язык интерфейса: русский.

## Уже реализовано

### Инфраструктура

- Flutter-проект создан.
- Зависимости прописаны в `pubspec.yaml`.
- Подключены `go_router`, `provider`, `cached_network_image`, `smooth_page_indicator`, `google_fonts`, `flutter_animate`, `badges`, `shimmer`.

### Тема и базовые сущности

- `lib/theme/app_theme.dart` — светлая тема, цвета, типографика, кнопки, поля, divider, chip.
- `lib/models/product.dart` — товар.
- `lib/models/category.dart` — категория.
- `lib/models/cart_item.dart` — позиция корзины.
- `lib/data/mock_data.dart` — mock-категории, товары, баннеры и методы поиска/фильтрации.

### Состояние

- `CartProvider` — корзина: add/remove/increment/decrement/clear, total, itemCount.
- `WishlistProvider` — избранное.
- `AuthProvider` — mock-авторизация и регистрация.

### Навигация

- `lib/router/app_router.dart` — `go_router` с `StatefulShellRoute`.
- Основные маршруты:
  - `/` — главная.
  - `/catalog` — каталог.
  - `/cart` — корзина.
  - `/profile` — профиль.
  - `/product/:id` — карточка товара.
  - `/search` — поиск.

### Экраны

- `lib/screens/splash/splash_screen.dart` — splash-анимация.
- `lib/screens/main_shell.dart` — нижняя навигация с бейджем корзины.
- `lib/screens/home/home_screen.dart` — баннеры, категории, рекомендации, новинки.
- `lib/screens/catalog/catalog_screen.dart` — категории, сортировка, сетка товаров.
- `lib/screens/product/product_detail_screen.dart` — галерея, размер, цвет, избранное, добавление в корзину.
- `lib/screens/cart/cart_screen.dart` — список товаров, количество, удаление, итог.
- `lib/screens/profile/profile_screen.dart` — гостевой экран, mock-login, заказы, избранное.
- `lib/screens/auth/auth_screen.dart` — вход/регистрация.
- `lib/screens/search/search_screen.dart` — поиск, подсказки, недавние запросы, результаты.

### Виджеты

- `lib/widgets/product_card.dart` — карточка товара.
- `lib/widgets/price_text.dart` — цена, старая цена, скидка.

## Известные ограничения

- Данные полностью mock, API-слоя пока нет.
- Оформление заказа пока заглушка.
- Google/Apple login декоративные.
- История заказов декоративная.
- Корзина, избранное и недавние поиски не сохраняются между запусками.
- Нет реальной модели остатков по размерам/цветам.
- Фото берутся из Unsplash, часть изображений повторяется.

## Рекомендованный следующий этап

1. Добавить репозитории: `ProductRepository`, `CartRepository`, `AuthRepository`, `OrderRepository`.
2. Сделать mock checkout-flow: контакты, доставка, самовывоз/СДЭК/Почта России, итог заказа.
3. Подготовить DTO под будущий backend и 1С: товары, варианты, остатки, цены, заказы.
4. Добавить сохранение корзины и избранного локально.
5. Расширить тесты на ключевые сценарии.
6. После стабилизации прототипа подключать реальный backend.

---

## Единая экосистема проектов

Этот проект не является отдельным продуктом. Он является частью общей экосистемы:

- `bugun-app` / «Квартал» — мобильное приложение для бегунов: захват территорий, баллы, клубы, соревнования.
- `САЙТ STAW` — сайт бренда/магазина, который далее будет переименован под общий бренд.
- `sport_store` — мобильное приложение спортивного магазина.

Перед началом работы обязательно прочитать `RECOMMENDATION.md`. Это общее рекомендательное письмо для всех трёх проектов: в нём собраны выводы по Nike, Adidas, Puma, Gymshark, Under Armour и описана стратегия общей экосистемы, а не изолированных приложений.

Общий смысл: приложения и сайт должны развиваться как связанная система — единый бренд, единые пользователи, заказы, лояльность, баллы, уведомления, контент и будущая backend/admin архитектура.


---

## Codex handoff ? 2026-06-09: shared backend account/profile

SportStore is part of the same ecosystem account as ???????. Backend is `D:\MyProjectsCLAUDE\backend`.

Current backend endpoints to use:

- `POST /v1/auth/phone/verify` ? phone login, dev code `1234`, returns JWT + user.
- `GET /v1/auth/me` ? current profile by Bearer JWT.
- `PATCH /v1/profile` ? update shared profile fields.
- `GET /v1/loyalty/account` ? shared points account.

Already partially changed in SportStore:

- `lib/data/api/api_config.dart`: dev baseUrl uses `http://127.0.0.1:8000/v1`; requires `adb reverse tcp:8000 tcp:8000` on phone.
- `lib/models/auth_user.dart`: added backend `id`, added `LoginProvider.phone`.
- `lib/data/repositories/auth_repository.dart`: added `loginByPhone(phone, code)` calling `/auth/phone/verify` in API repository.
- `lib/providers/auth_provider.dart`: added `loginByPhone(phone, code)`.
- `lib/screens/auth/auth_screen.dart`: added phone login UI with dev code `1234`.

Important pending work:

1. Convert profile editing to backend:
   - Add `updateProfile(...)` to `AuthRepository`.
   - Implement it in `ApiAuthRepository` via `PATCH /profile` with Bearer JWT.
   - Make `AuthProvider.updateProfile(...)` async and save the returned backend user.
   - Use local `auth_user` only as cache.

2. Refresh profile on startup when JWT exists:
   - `main.dart` already restores `api.authToken = prefs.getString('jwt')`.
   - After provider creation or first profile open, call `GET /auth/me` and update local user cache.

3. Clean up encoding artifacts:
   - Some newly inserted Russian fallback strings currently show as `????? ???????` / `????` because of a PowerShell encoding issue.
   - `dart analyze` passes, but UI strings should be fixed to proper UTF-8.

Validation already done after partial phone-auth work:

- `dart analyze lib` ? no issues.
- `flutter test` ? passed.
- `flutter build apk --debug` ? success.
- APK installed on phone.

Target test after Claude finishes profile sync:

1. Run backend on port 8000.
2. Run `adb reverse tcp:8000 tcp:8000`.
3. Login to ??????? by phone, code `1234`.
4. Edit profile in ???????.
5. Login to SportStore with same phone/code.
6. SportStore should show same backend `user.id` and same profile fields.

### Claude update — 2026-06-10: profile sync done

Pending work from the handoff is implemented in SportStore:

- `AuthRepository.updateProfile(current, {name, phone, city, avatarPath})` + `fetchMe()` added (abstract + Mock + Api). Api uses `PATCH /profile` and `GET /auth/me`; `ApiClient.patch` added.
- `AuthProvider.updateProfile(...)` is now async (returns `String?` error) and persists the backend user; `refreshFromServer()` runs on startup when a cached user exists. `_mergeKeepingLocal` preserves local addresses/avatar (backend doesn't store them yet).
- `edit_profile_screen._save` awaits `updateProfile` and shows errors.
- Encoding artifacts (`????? ???????` / `????`) fixed to proper UTF-8 Russian.

Validated: backend `PATCH /profile` + `GET /auth/me` return the same `user.id` and updated fields; `flutter analyze` clean; `flutter test` 4/4; `flutter build apk --debug` success.

Not yet done: on-device cross-app test (phone was disconnected from adb). To run: start backend on :8000, `adb reverse tcp:8000 tcp:8000`, login by phone (code `1234`), edit profile, then login to SportStore with the same phone — expect same `user.id`.
