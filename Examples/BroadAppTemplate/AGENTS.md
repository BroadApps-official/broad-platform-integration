# Инструкция агенту: backend-каталог и RU Billing

Этот файл действует для `BroadAppTemplate` и для нового host app, созданного из
него. Цель — сначала получить подтверждённый backend-контракт, а затем
подключить платформу без догадок и копирования значений другого приложения.

## Граница работы

- Не открывай и не изменяй платёжный кабинет: это не зона ответственности
  агента, который пишет app-side код.
- Не копируй production base URL, Bearer token, API key, email, checkout URL,
  SKU или персональные данные из другого приложения.
- Не выполняй настоящий purchase, restore, RU checkout или cancellation.
- Не начинай Swift-изменения, пока backend-раздел
  `Documentation/AppIntegrationPlan.md` не заполнен и неизвестные значения не
  отмечены `BLOCKED`.

## Сначала собери входные данные

В host app, `AppIntegrationPlan.md` и переданном API-контракте найди и выпиши:

1. место, где собирается base URL;
2. endpoint, method, headers и auth для каталога;
3. request/response DTO без реальных значений секретов;
4. единицу `price` и валюту;
5. backend product ID и способ его точного сопоставления с Adapty/App Store;
6. request checkout и поле ответа с payment URL;
7. источник подтверждения подписки после браузера;
8. источник подтверждения token balance;
9. endpoint отмены и смысл `canceled`, `alreadyCanceled`, `willRenew`;
10. offline/timeout/empty policy и backend kill switch.

Ищи не только название service. Проверяй фактические `URLRequest`/endpoint
builders, auth interceptor, DTO, composition root и место, где UI получает
результат.

## Что должно быть подтверждено

До кода должны быть известны catalog, checkout, status/policy и, если требуется,
cancel methods текущего приложения. Если значения не записаны в плане, задай
разработчику/team lead один прямой вопрос:

> Передайте для текущего приложения catalog, checkout, status/policy и cancel
> methods, auth dependency, JSON schema, price units и точные product IDs.

## Наводящие вопросы, если ответа не хватает

Задавай только вопросы, которые меняют реализацию:

- `price` приходит в рублях или minor units/копейках?
- `productId` совпадает с Adapty/App Store ID символ в символ?
- Если ID различаются, где находится явное соответствие?
- Какие поля обязательны: `title`, `kind`, `period`, `credits`, `currency`?
- `paymentMethods` приходит для каждой строки или задаётся configuration?
- Email обязателен для checkout и откуда host app его получает?
- Какой endpoint является authority для Premium после возврата из браузера?
- Где читать подтверждённый token balance?
- Как UI ведёт себя при пустом каталоге, 401, timeout и частично битом JSON?
- Текущий app уже переведён на правило `Storefront RU OR iPhone region RU`?

Если backend owner не дал ответ, запиши точный blocker и продолжай только
независимые части. Не придумывай production contract.

## Правила реализации

- Каталог передаётся массивом 1:1: не `filter`, не `sorted`, не `compactMap`,
  не `prefix`, не dictionary и не deduplication.
- 0, 1, 2 и N строк — нормальные входы. Ограничить карточки может только
  app-owned UI после получения полного platform result.
- Не выводи `kind`, ID или соответствие по имени SKU, цене, периоду или позиции.
- Почти одинаковые IDs не считаются совпадением.
- Возврат/закрытие browser sheet не означает оплату. Premium открывается после
  подтверждения entitlement/policy; токены — после подтверждения balance.
- `ru_pay` отсутствует/false/invalid — RU Billing закрыт. Не подставляй true.
- Региональный gate: App Store Storefront `RU/RUS` **или** регион iPhone
  `RU/RUS`; язык, клавиатура, IP и timezone не участвуют.
- Production domain и auth остаются app-owned configuration/dependencies.

## Что показать перед изменениями

Первый результат агента — не код, а короткий отчёт:

```text
BACKEND CONTRACT GIVEN
- catalog: method/path/auth/response shape
- checkout: method/path/body/response
- confirmation: subscription authority + token authority
- cancellation: method/path/response
- differences from current platform contract

QUESTIONS / BLOCKERS
- только неизвестные значения, влияющие на реализацию

PLAN
- app-owned configuration
- platform adapter/composition
- UI states
- safe tests without payment

BACKEND CONTRACT REVIEW REQUIRED
```

К реализации переходи после ответа разработчика. Детальный контракт:
[`../../Documentation/BackendProductCatalog.md`](../../Documentation/BackendProductCatalog.md).

## Если нужен спешл оффер RU Billing

Не добавляй отдельный campaign engine: экран, строгий gate и цикл 24/24
принадлежат обычному Adapty Special Offer. RU-ветка меняет только источник
продукта. Сначала верни разработчику этот список входных данных:

```text
RU SPECIAL OFFER GIVEN
- обычный paywall содержит strict bool special_offer = true
- отдельный Adapty placement special_offer настроен
- RU catalog: schema, price units, isSpecialOffer marker and exact IDs
- recurring/one-time mode, payment route, entitlement duration and legal copy
- checkout request and authoritative confirmation after browser return

QUESTIONS / BLOCKERS
- только неизвестные значения, меняющие реализацию

RU SPECIAL OFFER CONTRACT REVIEW REQUIRED
```

Правила:

- не открывай платёжный кабинет и не копируй значения другого приложения;
- RU-продукт выбирай только по строгому backend-маркеру `isSpecialOffer`
  (допустим согласованный snake_case alias); не выбирай по году, месяцу, цене,
  названию или позиции;
- обычный paywall исключает помеченную строку, а Special Offer не подставляет
  обычный тариф, если помеченной строки нет;
- если подтверждённый тип покупки и UI-текст противоречат друг другу, поставь
  `BLOCKED` и запроси team lead review;
- не смешивай `special_offer`, strict `ru_pay` и regional gate;
- используй фиксированные окно 24 часа и cooldown 24 часа общей реализации;
- возврат из Safari не является success: повторно проверь backend
  policy/entitlement;
- A/B-тесты RU Billing не поддержаны и находятся в разработке; не добавляй
  инструкции по их настройке;
- при неразрешённом gate, отсутствии помеченного продукта или пустом catalog
  ветка закрывается без настоящей оплаты.

Полная инструкция:
[`../../Documentation/RUSpecialOffer.md`](../../Documentation/RUSpecialOffer.md).
