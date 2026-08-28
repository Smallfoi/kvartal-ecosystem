# Часы: Apple, Garmin, Suunto — что подаём и что готовим

Как «Квартал» получает тренировки с часов. Для каждого источника: нужна ли заявка, что в ней
писать, сколько ждать и что делаем мы. Тексты заявок — готовые, их остаётся вставить в форму.

Дата: 29.08.2026. Смежное: `docs/LEAGUE_PLAN.md` §5 (место в плане), `docs/TESTFLIGHT.md` (Apple).

---

## 1. Коротко: три источника — три разных истории

| Источник | Нужна заявка? | Кто решает | Срок | Что даёт |
|---|---|---|---|---|
| **Apple Health / Apple Watch** | **нет** | никто | — | тренировки, пульс, шаги с iPhone и Apple Watch |
| **Garmin Connect** | да, партнёрская | Garmin | ответ за 2 рабочих дня | активности (30+ видов), пульс, сон, нагрузка |
| **Suunto Cloud API** | да, партнёрская | Suunto | до 2 недель | тренировки с GPS-треком, пульс, круги |

Важное различие, которое надо понимать до подачи:

- **Apple заявки не существует.** HealthKit — это не партнёрская программа, а обычная
  возможность iOS-приложения: включается галочкой в проекте. Никто её не «одобряет».
  Единственное, что нужно, — **аккаунт Apple Developer** (тот самый, что нужен и для
  TestFlight) и корректно описанное использование данных при проверке приложения в App Store.
  Проверка смотрит на три вещи: запрашиваем только те типы данных, которые реально используем;
  спрашиваем разрешение в момент, когда функция нужна, а не пачкой на старте; в политике
  конфиденциальности написано, что за данные и зачем. Данные о здоровье нельзя передавать
  в рекламу и в аналитику.
- **Garmin и Suunto** — партнёрские программы для организаций. Заявку подаёт юридическое лицо
  или ИП, не частное лицо. У нас ИП есть, данные ниже.

## 2. Что нужно сделать до подачи заявок

| Что | Зачем | Статус |
|---|---|---|
| Публичная страница политики конфиденциальности по постоянному адресу | обе формы просят ссылку; раньше `mata-club.ru/legal/privacy` открывал главную | **готово:** `mata-club.ru/legal/?doc=privacy` |
| Публичная страница пользовательского соглашения | там же | **готово:** `mata-club.ru/legal/?doc=terms` |
| Короткое описание приложения на английском | форма Garmin и Suunto — на английском | готово, §4 |
| Почта для партнёров | на неё придут ключи доступа; личная почта в спаме теряется | нужна от владельца, §6 |

## 3. Данные организации для форм

Берутся из публичных документов сайта (раздел «Контакты»):

```
Организация:  Индивидуальный предприниматель Татаринов Михаил Игнатьевич
              (в англоязычных формах: Individual Entrepreneur Mikhail Tatarinov)
ОГРНИП:       323140000031561
ИНН:          141100509786
Адрес:        Республика Саха (Якутия), г. Якутск, Россия
Сайт:         https://mata-club.ru
Email:        bmairussia@gmail.com
Телефон:      +7 914 222 59 69
Приложение:   МАТА Квартал (MATA Kvartal), Android — в тестировании, iOS — готовится
```

## 4. Описание приложения на английском (для обеих форм)

**Short (одна строка):**

> MATA Kvartal — a running app where every run counts in several leaderboards at once, so runners
> of any speed and age have their own league.

**Full (абзац, годится в поле «describe your application»):**

> MATA Kvartal is a running application built by MATA, a Russian sportswear brand. Runners record
> their runs in the app, earn points for activity and spend those points on the brand's gear —
> one account and one balance across our running app, our store and our website. The product is
> built around the idea that a single run should count in several leaderboards at once: absolute
> results, personal bests, consistency over 90 days, and an age- and gender-adjusted league, so
> that slower, older and beginner runners are not pushed out of competition. Many of our users
> train with a sports watch and do not carry a phone in their hand, so their activity is currently
> not counted at all. We need read access to completed workouts (start time, duration, distance,
> heart rate, GPS track where available) to award points for those sessions and include them in
> our leaderboards. We do not resell data, do not use it for advertising and do not share it with
> third parties.

**Use case (одна фраза, если поле отдельное):**

> Import completed workouts recorded on the user's watch so they receive activity points and
> appear in our leaderboards without carrying a phone.

**Data we request:** workout start time, duration, distance, activity type, average and maximum
heart rate, calories, GPS track where available.

**Expected volume (спрашивают в обеих формах):** до 5 000 подключённых устройств в первый год,
приложение работает в России.

## 5. Заявка в Garmin

**Куда:** страница программы — <https://developer.garmin.com/gc-developer-program/overview/>,
раздел «request the Garmin Connect Developer Program». Если формы на странице нет (в 2026 её
периодически убирают), пишем письмом на **connect-support@developer.garmin.com**.

**Что просим:** Activity API (готовые тренировки) и Health API (пульс и суточные показатели).
Начать достаточно с Activity API — он закрывает главную боль «бегаю с часами, очки не идут».

**Условия:** лицензионных платежей нет, но программа только для делового использования —
поэтому подаём от ИП, а не от частного лица. Ответ обещают в течение двух рабочих дней.

**Текст письма (если формы нет):**

```
Subject: Garmin Connect Developer Program — access request (MATA Kvartal, running app, Russia)

Hello,

We would like to request access to the Garmin Connect Developer Program (Activity API, and
Health API if available for our use case).

Company: Individual Entrepreneur Mikhail Tatarinov (OGRNIP 323140000031561, INN 141100509786),
Yakutsk, Russia
Website: https://mata-club.ru
Contact: bmairussia@gmail.com, +7 914 222 59 69
Application: MATA Kvartal — running app (Android live in testing, iOS in preparation)

MATA Kvartal is a running application built by MATA, a Russian sportswear brand. Runners record
their runs in the app, earn points for activity and spend those points on the brand's gear — one
account and one balance across our running app, our store and our website. A single run counts in
several leaderboards at once: absolute results, personal bests, consistency over 90 days, and an
age- and gender-adjusted league, so that slower, older and beginner runners are not pushed out of
competition.

Many of our users train with a Garmin watch and do not carry a phone in their hand, so their
activity is currently not counted at all. We are asking for read access to completed activities
(start time, duration, distance, activity type, heart rate, GPS track where available) in order to
award activity points for those sessions and include them in our leaderboards.

We do not resell data, do not use it for advertising and do not share it with third parties. Data
is stored on our own servers and is deleted when the user disconnects the integration.

Expected volume: up to 5,000 connected devices in the first year.

Privacy policy: https://mata-club.ru/legal/?doc=privacy
Terms: https://mata-club.ru/legal/?doc=terms

Thank you,
Mikhail Tatarinov
MATA
```

## 6. Заявка в Suunto

**Куда:** партнёрская форма на сайте Suunto — <https://www.suunto.com/partners/welcome-partners/>.
В форме обязательно отметить область интереса **«Suunto Cloud API»**. Вопросы и потеря доступов —
**partners@suunto.com**.

**Что даёт:** тренировки с GPS-треком, пульсом и кругами; суточная активность; можно отправлять
маршруты на часы (GPX) и тренировки (FIT) — это пригодится позже, в режиме «Цель».

**Условия:** программа для компаний, не для личных проектов. Нужно подписать API agreement
и перечислить в заявке всех разработчиков, которым нужен доступ (пока это один человек —
владелец как контакт; технический контакт добавим при необходимости). Рассматривают раз в неделю,
ответ до двух недель.

**Что писать в полях:** организация и контакты из §3, описание — из §4, область интереса —
Suunto Cloud API, коммерческое сотрудничество — «open to discuss» (отказываться сразу не стоит,
это не обязательство).

## 7. Что делаем мы, не дожидаясь ответов

Ни одна из заявок не блокирует работу. Порядок реализации:

1. **Импорт файлов GPX / TCX / FIT** — ни от кого не зависит. Сразу закрывает перенос истории
   из ушедших сервисов: Strava, Nike Run Club и adidas Running отдают архив тренировок файлами.
2. **Health Connect (Android)** — системное хранилище здоровья на Android, заявка не нужна.
   Через него приходят данные с большинства Android-совместимых часов и браслетов.
3. **Apple Health** — как только появится аккаунт Apple Developer.
4. **Garmin / Suunto** — по мере одобрения; адаптеры втыкаются в общий механизм импорта,
   который к тому моменту уже будет работать (`external_workout`, `docs/LEAGUE_PLAN.md` §5).

## 8. О чём договориться заранее

- **Пульс — это данные о здоровье.** Нужен отдельный экран согласия при подключении часов
  и упоминание в политике конфиденциальности: какие данные, зачем, сколько храним, как отключить.
- **Отключение = удаление.** Пользователь отключил часы — удаляем импортированные тренировки.
  Это требование и Garmin, и Apple, и здравого смысла.
- **Никакой рекламы на данных о здоровье.** Прямой запрет Apple; нарушение — снятие приложения.
- **Двойной учёт.** Тренировка с часов и наш собственный забег в те же минуты — одно и то же
  событие. Очки начисляем один раз, иначе получится дыра для накрутки.

## 9. Источники

- [Garmin Connect Developer Program — обзор](https://developer.garmin.com/gc-developer-program/)
- [Garmin Connect Developer Program — FAQ (сроки, платежи, деловое использование)](https://developer.garmin.com/gc-developer-program/program-faq/)
- [Garmin Activity API](https://developer.garmin.com/gc-developer-program/activity-api/)
- [Suunto APIzone — FAQ (как получить доступ, что отдаёт API)](https://apizone.suunto.com/faq)
- [Suunto — партнёрская программа](https://www.suunto.com/partners/welcome-partners/)
- [Apple — Health and Fitness для разработчиков](https://developer.apple.com/health-fitness/)
