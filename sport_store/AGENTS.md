# SportStore — Мобильное приложение спортивного магазина

## Описание проекта
Flutter-приложение для магазина спортивной одежды и экипировки.
Дизайн: чёрно-белый, в стиле Nike/Adidas — минималистичный, премиальный.
Язык интерфейса: только русский.
Платформы: iOS + Android.

## Путь к проекту
`D:\Мои проекты Codex\sport_store\`

## Технологический стек
- **Мобильное приложение:** Flutter (Dart)
- **Навигация:** go_router
- **Состояние:** provider
- **Изображения:** cached_network_image
- **Шрифты:** google_fonts (Inter)
- **Анимации:** flutter_animate
- **Бейджи:** badges
- **Shimmer-загрузка:** shimmer
- **Оплата (план):** ЮKassa
- **Пуш (план):** Firebase FCM
- **Бэкенд (план):** Node.js или FastAPI + PostgreSQL
- **Интеграция (план):** 1С через REST API (у клиента есть 1С-разработчик)
- **Хостинг (план):** Яндекс Cloud
- **Медиа-хранилище (план):** Яндекс Object Storage

---

## Что уже сделано ✅

### Инфраструктура
- [x] Flutter-проект создан командой `flutter create sport_store`
- [x] `pubspec.yaml` — все зависимости прописаны
- [x] Папка `assets/images/` создана

### Тема и дизайн
- [x] `lib/theme/app_theme.dart` — полная тема Nike-стиля:
  - Цвета: AppColors (black, white, grey100–grey800, red, success)
  - Типографика: Inter (displayLarge до labelLarge)
  - AppBarTheme, BottomNavigationBarTheme
  - ElevatedButton, OutlinedButton, InputDecoration, Chip, Divider

### Модели данных
- [x] `lib/models/product.dart` — модель Product (id, name, brand, categoryId, price, oldPrice, imageUrls, description, sizes, colors, isNew, isFeatured, rating, reviewCount, inStock + computed: isOnSale, discountPercent)
- [x] `lib/models/category.dart` — модель Category (id, name, emoji, imageUrl)
- [x] `lib/models/cart_item.dart` — модель CartItem (product, size, color, quantity + computed: total, key)

### Mock-данные
- [x] `lib/data/mock_data.dart` — полные тестовые данные:
  - 7 категорий (Все, Футболки, Худи, Брюки, Куртки, Кроссовки, Аксессуары)
  - 8 товаров со всеми полями, фото из Unsplash, ценами, размерами
  - 3 баннера для главного экрана
  - Методы: getByCategory(), getFeatured(), getNew(), search(), getById()

### Провайдеры состояния
- [x] `lib/providers/cart_provider.dart` — корзина (add, remove, increment, decrement, clear, itemCount, total)
- [x] `lib/providers/wishlist_provider.dart` — избранное (toggle, contains, count)

### Роутер
- [x] `lib/router/app_router.dart` — go_router с StatefulShellRoute:
  - `/` → HomeScreen
  - `/catalog` → CatalogScreen (поддержка ?category=xxx)
  - `/cart` → CartScreen
  - `/profile` → ProfileScreen
  - `/product/:id` → ProductDetailScreen
  - `/search` → SearchScreen

---

## Что осталось сделать ❌

### Экраны (все нужно создать)
- [ ] `lib/screens/main_shell.dart` — BottomNavigationBar с бейджем на корзине
- [ ] `lib/screens/home/home_screen.dart` — главный экран:
  - Hero-карусель баннеров (PageView + SmoothPageIndicator)
  - Горизонтальный список категорий (чипы)
  - Секция "Рекомендуем" (горизонтальный скролл карточек)
  - Секция "Новинки" (сетка 2 колонки)
  - AppBar с логотипом и иконкой поиска
- [ ] `lib/screens/catalog/catalog_screen.dart` — каталог:
  - Фильтр по категориям (горизонтальные чипы)
  - GridView товаров (2 колонки)
  - Сортировка (по цене, новинкам)
- [ ] `lib/screens/product/product_detail_screen.dart` — карточка товара:
  - Полноэкранная галерея фото
  - Выбор размера
  - Выбор цвета
  - Кнопка "В корзину"
  - Кнопка избранного
  - Описание, рейтинг
- [ ] `lib/screens/cart/cart_screen.dart` — корзина:
  - Список товаров с фото, изменение количества
  - Итоговая сумма
  - Кнопка "Оформить заказ"
- [ ] `lib/screens/profile/profile_screen.dart` — профиль:
  - Имя, email пользователя
  - История заказов
  - Избранное
  - Настройки
- [ ] `lib/screens/search/search_screen.dart` — поиск:
  - Поисковая строка
  - Результаты в виде списка

### Виджеты (переиспользуемые)
- [ ] `lib/widgets/product_card.dart` — карточка товара для каталога/главной
- [ ] `lib/widgets/price_text.dart` — отображение цены (старая/новая + скидка)

### Точка входа
- [ ] `lib/main.dart` — обновить: MultiProvider + MaterialApp.router + AppTheme
- [ ] `lib/app.dart` — корневой виджет приложения

### Финал
- [ ] `flutter pub get` — установить зависимости
- [ ] Запуск и проверка на эмуляторе

---

## Архитектура папок

```
lib/
├── main.dart               ❌ нужно переписать
├── app.dart                ❌ создать
├── theme/
│   └── app_theme.dart      ✅ готово
├── router/
│   └── app_router.dart     ✅ готово
├── models/
│   ├── product.dart        ✅ готово
│   ├── category.dart       ✅ готово
│   └── cart_item.dart      ✅ готово
├── data/
│   └── mock_data.dart      ✅ готово
├── providers/
│   ├── cart_provider.dart  ✅ готово
│   └── wishlist_provider.dart ✅ готово
└── screens/
    ├── main_shell.dart     ❌ создать
    ├── home/
    │   └── home_screen.dart ❌ создать
    ├── catalog/
    │   └── catalog_screen.dart ❌ создать
    ├── product/
    │   └── product_detail_screen.dart ❌ создать
    ├── cart/
    │   └── cart_screen.dart ❌ создать
    ├── profile/
    │   └── profile_screen.dart ❌ создать
    └── search/
        └── search_screen.dart ❌ создать
```

---

## Дизайн-принципы (Nike-стиль)
- Фон: белый (#FFFFFF)
- Основной цвет: чёрный (#000000)
- Шрифт: Inter, жирный для заголовков
- Кнопки: прямоугольные (radius = 0), чёрный фон, белый текст
- Карточки: без тени, только изображение + текст
- Отступы: 16px стандарт, 24px для секций

---

## Бизнес-контекст
- Магазин спортивной одежды и экипировки в Якутске
- Система учёта: 1С (есть разработчик для выгрузки API)
- Оплата: ЮKassa
- Доставка: своими курьерами + СДЭК + Почта России + самовывоз
- Пуш-уведомления: Firebase FCM (план)
- Медиа (фото/видео/описания товаров): хранить отдельно от 1С в Яндекс Object Storage

---

## Единая экосистема проектов

Этот проект не является отдельным продуктом. Он является частью общей экосистемы:

- `bugun-app` / «Квартал» — мобильное приложение для бегунов: захват территорий, баллы, клубы, соревнования.
- `САЙТ STAW` — сайт бренда/магазина, который далее будет переименован под общий бренд.
- `sport_store` — мобильное приложение спортивного магазина.

Перед началом работы обязательно прочитать `RECOMMENDATION.md`. Это общее рекомендательное письмо для всех трёх проектов: в нём собраны выводы по Nike, Adidas, Puma, Gymshark, Under Armour и описана стратегия общей экосистемы, а не изолированных приложений.

Общий смысл: приложения и сайт должны развиваться как связанная система — единый бренд, единые пользователи, заказы, лояльность, баллы, уведомления, контент и будущая backend/admin архитектура.
