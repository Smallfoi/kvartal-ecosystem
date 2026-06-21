# Единый контракт данных экосистемы STAW

> **Единый источник правды** для трёх продуктов: «Квартал» (Runner App), Sport Store (App) и Сайт.
> Все три приложения и backend реализуют ОДНИ и те же сущности, эндпоинты и потоки.
> Менять контракт — только здесь, синхронно во всех проектах. Связанные документы: `RECOMMENDATION.md`, `ECOSYSTEM.md`.
>
> Статус: контракт согласован с уже реализованными в Sport Store моделями (DTO) и репозиториями
> (`sport_store/lib/data/repositories/*`, `sport_store/lib/models/*`). Backend пока не поднят
> (`ApiConfig.useMock = true`). При запуске backend все три приложения переключаются на эти эндпоинты.

---

## 0. Принципы

1. **Один аккаунт (SSO).** Один пользователь = один `userId`. Логин/регистрация в любом приложении → единый JWT работает во всех трёх.
2. **Один баланс баллов.** Баллы начисляются в любом продукте (бег в «Квартале», покупка в Store), баланс общий.
3. **Одни данные.** Товары, заказы, уведомления, кроссовки — одни и те же сущности во всех приложениях.
4. **Формат.** REST + JSON. Все даты — ISO 8601 (UTC). Деньги — рубли (число). `id` — строка.
5. **Авторизация.** Заголовок `Authorization: Bearer <JWT>` на всех приватных эндпоинтах.
6. **Источник цен/остатков — 1С.** Описания/фото/теги/видео — admin-панель. Контракт — то, что отдаёт backend наружу (не внутреннее представление 1С).

---

## 1. Сервисы (микро-домены)

| Сервис | Назначение | Кто пишет | Кто читает |
|---|---|---|---|
| **Auth** | SSO, JWT, профиль | все три | все три |
| **Catalog** | товары, категории, баннеры | admin/1С → backend | Store, Сайт |
| **Order** | заказы, статусы | Store, Сайт | Store, Сайт, admin |
| **Loyalty** | баллы (единый баланс) | Квартал, Store, Сайт | все три |
| **Shoes** | кроссовки пользователя (трекер износа) | Store (покупка), Квартал (км) | Квартал, Store |
| **Notification** | пуш/лента (FCM) | backend | все три |

---

## 2. Сущности (общие модели)

> JSON-формы совпадают с DTO Sport Store (`toJson`/`fromJson`). Новые приложения используют их 1-в-1.

### 2.1 User (Auth)
```json
{
  "id": "u_123",
  "name": "Алексей Иванов",
  "email": "alex@mail.ru",
  "phone": "+79990000000",
  "provider": "email | google | apple",
  "avatarPath": "https://cdn.staw.ru/u/123.jpg",
  "addresses": [ /* SavedAddress[] */ ]
}
```
`SavedAddress`:
```json
{ "label": "Дом", "city": "Москва", "street": "ул. Ленина", "house": "12А", "apartment": "45", "postalCode": "101000" }
```

### 2.2 Category / Product (Catalog)
```json
// Category
{ "id": "shoes", "name": "Кроссовки", "emoji": "👟", "imageUrl": "https://cdn.staw.ru/cat/shoes.jpg" }
```
```json
// Product
{
  "id": "3",
  "name": "Кроссовки Air Runner X1",
  "brand": "STAW",
  "categoryId": "shoes",
  "price": 12990,
  "oldPrice": 15990,
  "imageUrls": ["https://cdn.staw.ru/p/3_0.jpg", "..."],
  "description": "…",
  "sizes": ["41","42","43"],
  "colors": ["Чёрный/Серый"],
  "isNew": true,
  "isFeatured": true,
  "rating": 4.7,
  "reviewCount": 203,
  "inStock": true
}
```
> Расширения на будущее (из RECOMMENDATION ч.3): `subcategoryId`, `videoUrl`, `shortDescription`, `stockPerSizeColor`, `isBestseller`, `stockCount`, `materialComposition`, `careInstructions`, `weight`.

### 2.3 Order (Order)
```json
{
  "id": "SS-61439",
  "userId": "u_123",
  "items": [
    { "productId": "2", "productName": "Худи Essential Fleece", "productBrand": "STAW",
      "imageUrl": "…", "price": 5990, "size": "L", "color": "Тёмно-синий", "quantity": 1 }
  ],
  "subtotal": 5990,
  "deliveryCost": 300,
  "pointsRedeemed": 430,
  "total": 5860,
  "checkoutData": {
    "name": "Алексей Иванов", "phone": "+7…", "email": "alex@mail.ru",
    "deliveryType": "pickup | courier | cdek | russianPost",
    "city": "Москва", "street": "…", "house": "…", "apartment": "…", "postalCode": "…",
    "paymentType": "card | cash | sbp"
  },
  "status": "pending | processing | shipped | delivered | cancelled",
  "createdAt": "2026-06-05T13:09:00Z"
}
```
> В Sport Store уже есть всё, кроме `userId` и `pointsRedeemed` — добавить при подключении backend (см. §6 Пробелы).

### 2.4 Loyalty (Loyalty) — ЯДРО ЭКОСИСТЕМЫ
```json
// LoyaltyAccount
{ "userId": "u_123", "balance": 430, "level": "basic | silver | gold | platinum" }
```
```json
// LoyaltyTransaction (общая для Квартала и Store)
{
  "id": "tx_1",
  "userId": "u_123",
  "amount": 120,            // + начисление, − списание
  "source": "runnerRun | runnerTerritory | runnerCompetition | purchase | review | registration | birthday | referral | redeem",
  "description": "Пробежка 12.0 км",
  "orderId": "SS-61439",    // null если не покупка
  "runId": "run_88",        // null если не Runner App
  "createdAt": "2026-06-05T08:00:00Z"
}
```
**Правила (RECOMMENDATION ч.11.5):** 1 балл = 1 ₽; списание макс 30% заказа; мин остаток для списания 50; срок 12 мес.
**Уровни:** basic 0–199 (1%) · silver 200–499 (2%) · gold 500–999 (3%) · platinum 1000+ (5%).
**Начисление:** бег 1 км = 10 · захват территории = 50 · победа = 200 · покупка = 1/10 ₽ · первый заказ +50 · отзыв с фото +10 · регистрация +20.

### 2.5 ShoeAsset (Shoes) — связка Store ↔ Квартал
> Реализует идею «трекер износа кроссовок» из `IDEAS.md`. Купил в Store → зарегистрировались в Квартале.
```json
{
  "id": "shoe_1",
  "userId": "u_123",
  "productId": "3",
  "orderId": "SS-61439",
  "model": "Air Runner X1",
  "imageUrl": "…",
  "purchasedAt": "2026-06-05T13:09:00Z",
  "totalKm": 0,
  "maxKm": 600,
  "retired": false
}
```

### 2.6 Notification (Notification)
```json
{ "id": "n_1", "userId": "u_123", "title": "Заказ №SS-61439 доставлен",
  "body": "…", "type": "order | promo | system", "orderId": "SS-61439",
  "read": false, "createdAt": "2026-06-05T14:00:00Z" }
```

### 2.7 LegalDocument / UserConsent (Legal) — единые документы и аудит согласий
Версионируемые документы (тип+версия) и факт согласия пользователя — для launch-gate
(`docs/LAUNCH_READINESS.md` §3/§13). Текст документов заполняет юрист.
```json
// LegalDocument
{ "id": "1", "type": "terms | privacy | pd_consent | marketing | offer | loyalty | club",
  "version": "1.0", "title": "Пользовательское соглашение", "body": "…",
  "required": true, "publishedAt": "2026-06-21T00:00:00Z", "accepted": false }
// UserConsent (в /legal/consents)
{ "id": "10", "type": "terms", "version": "1.0", "acceptedAt": "…",
  "source": "kvartal", "revokedAt": null, "active": true }
```

---

## 3. Эндпоинты

> Базовый URL: `ApiConfig.baseUrl` (пример: `https://api.staw.ru/v1`). Реализованы в Sport Store как `Api*Repository`.

### Auth
```
POST /auth/register            { name, email, password } → { token, user }
POST /auth/login               { email, password }       → { token, user }
POST /auth/oauth/google                                  → { name, email }      (handshake)
POST /auth/oauth/apple                                   → { name, email }
POST /auth/oauth/complete      { email, provider, name, phone } → { token, user }
POST /auth/password/forgot     { email }                 → 200
POST /auth/password/reset      { password }              → 200
PUT  /auth/password            { old, new }              → 200
GET  /auth/me                                            → user   (incl. privacy)
```

### Account (приватность и удаление, LAUNCH_READINESS §2/§13)
```
GET   /account/privacy                                   → { profilePublic, routePublic, realtimePublic }
PATCH /account/privacy   { routePublic, ... }            → privacy   (по умолчанию всё закрыто)
POST  /account/delete    { confirm: true }               → { ok, deleted{...} }  (необратимо, Bearer)
```

### Catalog
```
GET /categories                         → Category[]
GET /products                           → Product[]
GET /products?category=:id              → Product[]
GET /products?featured=true             → Product[]
GET /products?new=true                  → Product[]
GET /products/:id                       → Product
GET /products/search?q=:q               → Product[]
GET /brands                             → string[]
GET /sizes                              → string[]
GET /products/price-range               → { min, max }
GET /banners                            → Banner[]
```

### Order
```
POST /orders     { items, checkoutData, pointsRedeemed } → Order   (создаёт заказ + ShoeAsset для обуви)
GET  /orders                                             → Order[] (текущего пользователя)
GET  /orders/:id                                         → Order
```

### Loyalty (единый баланс)
```
GET  /loyalty/account                   → { balance, level, transactions: LoyaltyTransaction[] }
POST /loyalty/transactions  LoyaltyTransaction → 200   (Квартал шлёт бег/территории, Store — покупки/списания)
```

### Shoes (трекер износа)
```
GET  /shoes                             → ShoeAsset[]            (Квартал показывает ресурс)
POST /shoes/:id/distance  { km }        → ShoeAsset              (Квартал добавляет км после пробежки)
```

### Notification
```
GET  /notifications                     → Notification[]
POST /notifications/read  { ids: [] }   → 200
POST /devices  { fcmToken, platform }   → 200                    (регистрация устройства для пуша)
```

### Legal / Consents (единые документы и согласия)
```
GET  /legal/documents                   → LegalDocument[]   (текущие опубликованные; accepted — если Bearer)
POST /legal/consent     { accept:[type], source } | { type, source } → { recorded }   (Bearer)
GET  /legal/consents                    → UserConsent[]     (аудит согласий пользователя, Bearer)
POST /legal/consent/revoke  { type }    → { revoked }       (отзыв необязательного согласия, Bearer)
```

---

## 4. Потоки обмена между приложениями

### 4.1 Единый аккаунт (SSO)
```
Регистрация в любом приложении → POST /auth/register → { token, user }
JWT сохраняется → работает в Квартале, Store и на Сайте. Профиль/баллы/заказы общие.
```

### 4.2 Баллы: Квартал → Store
```
Пробежал 12 км в Квартале → POST /loyalty/transactions {source:"runnerRun", amount:120}
              ↓ единый баланс на backend
Открыл Store → GET /loyalty/account → видит 430 баллов
В корзине применяет → заказ с pointsRedeemed → POST /loyalty/transactions {source:"redeem", amount:-430}
```

### 4.3 Покупка → кроссовки (Store → Квартал)
```
Купил кроссовки в Store → POST /orders → backend создаёт ShoeAsset {productId, userId, maxKm}
              ↓
Квартал → GET /shoes → показывает "Осталось ~230/600 км"
Каждая пробежка → POST /shoes/:id/distance {km} → ресурс убывает
Ресурс на исходе → пуш + рекомендация новой модели из Store (POST /notifications backend)
```

### 4.4 Статус заказа → пуш во все приложения
```
Backend меняет статус заказа → создаёт Notification → FCM-пуш
Все три приложения: GET /notifications → единая лента
```

---

## 5. Реализация в Sport Store (уже есть)

| Слой | Файлы |
|---|---|
| DTO | `lib/models/{product,category,order,auth_user,loyalty,app_notification}.dart` (`toJson`/`fromJson`) |
| Контракты | `lib/data/repositories/{product,auth,order,loyalty}_repository.dart` (abstract + Mock + **Api**) |
| Переключатель | `lib/data/api/api_config.dart` (`useMock`), `api_client.dart` (JWT, timeout) |

Переход на backend: поднять API по этому контракту → `ApiConfig.baseUrl` + `useMock = false`. Экраны не меняются.

---

## 6. Пробелы / TODO для полной согласованности

- [ ] Добавить `userId` в Order и Loyalty при подключении backend (сейчас локально не нужен).
- [ ] Добавить `pointsRedeemed` в модель `Order` Sport Store (сейчас списание считается отдельно в Loyalty).
- [x] Сервис **Shoes** + модель `ShoeAsset` — **backend готов**: авто-создание при заказе обуви (`POST /orders` → `store_shoes`), `GET /shoes`, `POST /shoes/:id/distance`. Осталось: UI трекера в Квартале (GET /shoes) и начисление км после пробежки.
- [ ] `runId` в LoyaltyTransaction (для Runner-источников).
- [ ] Расширить `Product` полями из RECOMMENDATION ч.3 (видео, остатки по вариантам, состав).
- [ ] Эндпоинт `/auth/me` + хранение `userId` для всех сущностей.
