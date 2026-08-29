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

## 5. Заявка в Garmin — что именно заполнять

**Формы заявки на сайте программы больше нет** — вместо неё висит «Stay tuned for
more updates on the program». Проверено 29.08.2026 на
<https://developer.garmin.com/gc-developer-program/overview/>. Единственный рабочий
путь — форма обращения к разработчикам:

**<https://www.garmin.com/en-US/forms/developercontactus/>**

Полей всего шесть, вся заявка — три минуты. Значения (звёздочкой отмечены
обязательные):

| Поле формы | Что вписать |
|---|---|
| Name * | `Mikhail Tatarinov` |
| Company name * | `MATA (IE Mikhail Tatarinov)` |
| Email address * | `bmairussia@gmail.com` |
| Country & State/Province/Region * | `Russia` |
| **Which developer program are you interested in?** * | **`Garmin Connect Developer Program`** — это ключевой выбор, в списке есть похожие (Connect IQ SDK, Garmin Health SDKs), они не про то |
| Message | текст ниже |
| reCAPTCHA | пройти самому — это то, чего не может сделать автоматика |

**Текст в поле Message** (копировать целиком):

```
Hello,

We would like to request access to the Garmin Connect Developer Program
(Activity API, and Health API if it fits our use case).

MATA Kvartal is a running application built by MATA, a Russian sportswear brand.
Runners record their runs in the app, earn points for activity and spend those
points on the brand's own gear — one account and one balance across our running
app, our store and our website. A single run counts in several leaderboards at
once: total distance, personal bests, consistency over 90 days, and an age- and
gender-adjusted league, so that slower, older and beginner runners are not pushed
out of competition.

Many of our users train with a Garmin watch and do not carry a phone in their
hand, so their activity is currently not counted at all. We are asking for read
access to completed activities (start time, duration, distance, activity type,
heart rate, GPS track where available) in order to award activity points for those
sessions and include them in our leaderboards.

We do not resell data, do not use it for advertising and do not share it with
third parties. Data is stored on our own servers and is deleted when the user
disconnects the integration.

Company: Individual Entrepreneur Mikhail Tatarinov (OGRNIP 323140000031561,
INN 141100509786), Yakutsk, Russia
Website: https://mata-club.ru
Application: MATA Kvartal — Android in testing, iOS in preparation
Expected volume: up to 5,000 connected devices in the first year
Privacy policy: https://mata-club.ru/legal/?doc=privacy
Terms: https://mata-club.ru/legal/?doc=terms

Thank you,
Mikhail Tatarinov
```

Ответ обещают в течение двух рабочих дней. Лицензионных платежей нет, но программа
только для делового использования — поэтому подаём от ИП.

## 6. Заявка в Suunto — что именно заполнять

Анкета живёт не на сайте Suunto, а отдельно:

**<https://survey.alchemer.eu/s3/90553908/PARTNER-Become-a-Suunto-Partner>**
(со страницы <https://www.suunto.com/partners/welcome-partners/> — кнопка «Apply now»)

Заполнять **на английском**, займёт около пяти минут, ответ в течение двух недель.
Важно знать заранее: **при отправке подписывается API Agreement** (юридическое
соглашение с Suunto Oy) и оформляется подписка на их рассылку для партнёров —
отписаться можно потом.

Анкета из шести шагов. Что отвечать:

**Шаг 1 — вводный.** Просто «Next».

**Шаг 2 — Contact information.**

| Поле | Значение |
|---|---|
| First Name / Last Name | `Mikhail` / `Tatarinov` |
| Title | `Founder` |
| Company Name | `MATA (IE Mikhail Tatarinov)` |
| City / Country | `Yakutsk` / `Russia` |
| Email Address | `bmairussia@gmail.com` |
| Phone Number | `+7 914 222 59 69` |
| Company website | `https://mata-club.ru` |

**Шаг 3 — про продукт.**

- *Name for this:* `MATA Kvartal — running app`
- *Where to learn more:* `https://mata-club.ru`
- *Describe the tools/app you are working with:*
  `A running app by MATA, a Russian sportswear brand. Runners record runs, earn
  points for activity and spend them on the brand's gear — one account and one
  balance across the running app, the store and the website. A single run counts
  in several leaderboards at once: distance, personal bests, consistency over
  90 days, and an age- and gender-adjusted league.`
- *Key benefits:* `Runners of any speed and age have a leaderboard they can win.
  Activity converts into real gear instead of abstract points.`
- *Describe your customers:* `Amateur runners in Russia, from beginners to
  competitive age-groupers. A typical user runs 2–4 times a week in their own
  neighbourhood; many train with a sports watch and do not carry a phone.`
- *Size of customer base:* `Early stage: Android build in closed testing, up to
  5,000 connected users expected in the first year.`
- *Which countries:* `Russia (primary market), CIS`
- *Прошлый опыт с Suunto:* отметить `Other` → `No prior integration with Suunto`

**Шаг 4 — направления сотрудничества.** Отметить **только**
`I want to have access to Suunto Cloud Api`. Остальные блоки (Value Pack,
Movesense, SuuntoPlus Sport apps) — не наша история, лишние галочки затянут
рассмотрение.

- *What type of data would you like to use and for what purpose:*
  `Completed workouts (start time, duration, distance, sport type, heart rate and
  GPS track where available). We use them to award activity points and include
  the workout in our leaderboards, so that users who train with a Suunto watch
  and without a phone are not left out. We do not resell data and do not use it
  for advertising.`

**Шаг 5 — API Agreement и права доступа.** Здесь читается и принимается соглашение,
перечисляются разработчики (имя, фамилия, email — можно только себя) и отмечается,
какие данные нужны. **Отмечать только `Get workout data`** — просить минимум и
правильно, и быстрее рассматривается. Остальное (шаги, сон, маршруты, планы) нам
сейчас не нужно; если понадобится — расширим.

**Шаг 6** — отправка.

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
