# КВАРТАЛ — CLAUDE.md

## Проект
Городское беговое соревновательное приложение для Якутска.  
Пользователи бегают по городу, захватывают гексагоны на карте, соревнуются в клубах.

## Стек
- **Frontend:** Flutter 3.32 (Dart) — iOS + Android
- **Backend:** Go (Fiber v2) + PostgreSQL + PostGIS
- **State:** Riverpod 2.x
- **Maps:** flutter_map + OpenStreetMap
- **GPS:** geolocator + background_locator_2
- **Navigation:** go_router
- **Auth:** JWT + SMS (smsc.ru) + VK OAuth + Google + Apple Sign In

## Структура проекта
```
lib/
├── main.dart
├── core/
│   ├── theme/          # AppTheme, AppColors
│   ├── router/         # GoRouter config
│   └── constants/      # AppStrings и прочее
├── features/
│   ├── map/            # Карта города + гексагоны
│   ├── run/            # GPS-трекинг тренировок
│   ├── leaderboard/    # Рейтинги (личный, клубы, районы)
│   ├── club/           # Клубы и командные вызовы
│   ├── profile/        # Профиль, бейджи, статистика
│   └── auth/           # Авторизация
└── shared/
    └── widgets/        # Переиспользуемые виджеты (MainScaffold, etc.)
```

## Дизайн
- **Режим:** Dark mode first
- **Акцент:** Electric blue `#0A84FF`
- **Фон:** `#0D0D0D` (bgDark), `#1A1A1A` (bgSurface)
- **Типографика:** жирная, крупная — читается на бегу
- Все цвета — в `AppColors`, тема — в `AppTheme.dark`

## Ключевые механики
- **Гексагоны:** H3-сетка уровня 9 (~174м), захват при пробеге ≥50м, удержание 72ч
- **Морозный коэффициент:** бонус к очкам при беге в мороз (якутская специфика)
- **Античит:** блокировка при скорости >40 км/ч, серверная валидация GPS

## Соглашения
- Feature-first структура: каждая фича в `lib/features/<name>/presentation/`
- Состояние через Riverpod providers
- Навигация через GoRouter (ShellRoute для таббара)
- Экраны не содержат бизнес-логику — только UI
- Строки — в `AppStrings`, не хардкодить в виджетах

## MVP (Sprint 1–4)
- [x] Структура проекта + навигация (5 табов)
- [x] Тема (тёмная, electric blue)
- [x] Экраны: Карта, Бег, Рейтинг, Клуб, Профиль (UI-скелеты)
- [ ] GPS-трекинг (geolocator)
- [ ] Карта с OpenStreetMap (flutter_map)
- [ ] Авторизация (SMS)
- [ ] Захват гексагонов (H3)

---

## Совместная работа Claude + Codex

Перед продолжением работы читать `CODEX_HANDOFF.md` и последнюю запись `HISTORY.md`.

Если работу продолжает Codex после Claude или Claude после Codex:

- не считать изменения другого агента временными;
- сначала сверить текущее состояние файлов с историей;
- после сессии обязательно обновить `HISTORY.md`;
- если был изменён план или архитектурное решение, записать причину в историю.

---

## Единая экосистема проектов

Этот проект не является отдельным продуктом. Он является частью общей экосистемы:

- `kvartal-app` / «Квартал» — мобильное приложение для бегунов: захват территорий, баллы, клубы, соревнования.
- `САЙТ STAW` — сайт бренда/магазина, который далее будет переименован под общий бренд.
- `sport_store` — мобильное приложение спортивного магазина.

Перед началом работы обязательно прочитать `RECOMMENDATION.md`. Это общее рекомендательное письмо для всех трёх проектов: в нём собраны выводы по Nike, Adidas, Puma, Gymshark, Under Armour и описана стратегия общей экосистемы, а не изолированных приложений.

Общий смысл: приложения и сайт должны развиваться как связанная система — единый бренд, единые пользователи, заказы, лояльность, баллы, уведомления, контент и будущая backend/admin архитектура.

## Update 2026-06-13: GitHub workflow and Django migration

Project owner approved a new direction:

- All future work should move to GitHub-based workflow.
- Preferred repository model: monorepo `kvartal-ecosystem` containing KVARTAL, SportStore, website/admin and backend.
- Backend will be migrated gradually from current FastAPI prototype to Django + Django REST Framework.
- Do not delete FastAPI until Django has compatible endpoints and mobile apps are verified.
- Keep API contracts stable during migration, especially auth/profile endpoints.

Read: `CLAUDE_HANDOFF_GITHUB_DJANGO_2026-06-13.md` before backend or repository-structure work.

