# Каталог RU-продуктов с backend

Эта инструкция отвечает на практический вопрос: **как получить продукты с
backend и передать их в общий RU Billing flow**. Она описывает границу
платформы. URL, авторизация и конкретная схема ответа принадлежат приложению и
согласуются с backend-командой.

## Что делает каждая сторона

```text
backend
  отдаёт массив продуктов и доступные способы оплаты
        ↓
конфигурация host app
  передаёт URL, headers/auth и timeout
        ↓
BroadMonetization URLSession repository + decoder
  выполняют запрос, проверяют поля и создают RUCatalogProduct для каждой строки 1:1
        ↓
BroadMonetization use case
  сопоставляет выбранный Adapty/App Store product по точному product ID
        ↓
BroadUIFlows или собственный UI приложения
  показывает все полученные продукты и запускает выбранный способ оплаты
```

Платформа **не знает** production URL и токены конкретного приложения. Это не
недостающая функция: секреты и app-specific настройки нельзя хранить в public
package. Платформа даёт HTTP repository, модели, decoder, gate, сопоставление и
checkout flow.

## Методы, которые получает разработчик

До реализации team lead/backend owner передаёт методы текущего приложения:

| Операция | Пример пути | Назначение |
|---|---|---|
| catalog | `GET /v1/tokens/products` | подписки, coupon и пакеты токенов |
| checkout | `POST /v1/billing/cloudpayments/checkout` | создать ссылку на RU-оплату |
| status/policy | `GET /v1/policy/effective` | подтвердить подписку/права после оплаты |
| cancel, если есть renewal | `POST /v1/billing/cloudpayments/cancel` | отключить автопродление |

Пути в таблице — пример формы контракта. Агент не открывает платёжный кабинет и
не подбирает endpoints по другому приложению: точные URL, auth и schema должны
быть записаны в `AppIntegrationPlan.md`.

### Обезличенный API-shape пример

```http
GET https://<app-backend>/v1/tokens/products
Authorization: Bearer <current-user-access-token>
Accept: application/json
```

```json
{
  "products": [
    {
      "productId": "premium_month_ru",
      "title": "Premium на месяц",
      "kind": "subscription",
      "period": "month",
      "price": 499,
      "currency": "RUB"
    },
    {
      "product_id": "tokens_100_ru",
      "title": "100 токенов",
      "kind": "tokens",
      "price": 199,
      "currency": "RUB",
      "credits": 100
    }
  ]
}
```

```http
POST https://<app-backend>/v1/billing/cloudpayments/checkout
Authorization: Bearer <current-user-access-token>
Content-Type: application/json

{
  "productId": "premium_month_ru",
  "customerEmail": "buyer@example.com"
}
```

```json
{
  "paymentId": "payment_123",
  "paymentUrl": "https://<payment-page>",
  "status": "pending",
  "expiresAt": "2026-08-30T12:30:00Z"
}
```

Закрытие `paymentUrl` не доказывает success. Подписка подтверждается повторным
`GET /v1/policy/effective`, а токены — изменившимся backend balance/wallet.

В API отдельный `appStoreProductId` не гарантирован.
До реализации зафиксируйте одно из двух: backend `productId` точно совпадает с
Adapty/App Store ID либо существует явное server/app-owned соответствие. Нельзя
выводить соответствие из цены, периода, названия или позиции строки.

### Пример — это не production configuration

Не переносите из другого приложения production domain, Bearer token, SKU и credentials.
Не повторяйте локальные `filter`, `sorted`, `compactMap`, dictionary/dedup,
угадывание `kind` по имени SKU, language gate, permissive `ru_pay` fallback или
optimistic Premium после возврата из браузера. Эти расхождения показывают,
зачем нужен единый adapter; они не становятся contract платформы.

## Что получить у backend-команды до разработки

| Нужно уточнить | Почему это обязательно |
|---|---|
| URL, HTTP method и auth | Без них нельзя выполнить production request |
| Полная JSON schema | Decoder не должен угадывать названия и типы полей |
| Единица `price` | `499` может означать 499 ₽ или 4,99 ₽ |
| Валюта | Форматирование и legal copy зависят от неё |
| Стабильный backend product ID | По нему создаётся checkout |
| Точный App Store/Adapty product ID | По нему Apple product связывается с RU product |
| `sbp`/`card` для каждой строки или всего ответа | Определяет доступные кнопки |
| Empty/error/offline policy | UI должен знать: Apple-only, retry или blocking error |

Если хотя бы одно значение неизвестно, пометьте каталог `BLOCKED` в
`Documentation/AppIntegrationPlan.md`; не подставляйте пример как production.
Пошаговый порядок для Codex/Claude находится в
[`Examples/BroadAppTemplate/AGENTS.md`](../Examples/BroadAppTemplate/AGENTS.md).

## Поддерживаемый плоский ответ

Для простого ответа вида `{ "products": [...] }` используйте готовый
`FlatRUCatalogResponseDecoder`. Он принимает camelCase и snake_case для ID.

```json
{
  "products": [
    {
      "productId": "premium_month_ru",
      "appStoreProductId": "com.company.app.premium.month",
      "title": "Premium на месяц",
      "kind": "subscription",
      "period": "month",
      "price": 499,
      "currency": "RUB",
      "paymentMethods": ["sbp", "card"]
    }
  ]
}
```

В этом adapter `price` — число в **основных единицах валюты**: `499` означает
499 ₽. Если backend отдаёт копейки/minor units, вложенный envelope, другие
названия или несколько endpoints, напишите небольшой app-owned decoder и
оставьте общий domain/use-case слой без изменений.

## Подключение

```swift
let wire = RUBillingWireAdapters.broadAppsFlatCatalog(
    supportedMethods: [.sbp, .card]
)

let ruBillingFactory = RUBillingCompositionFactory(
    configuration: ruBillingConfiguration,
    dependencies: ruBillingDependencies,
    wire: wire
)
```

`ruBillingConfiguration` хранит app-owned HTTPS endpoints и timeout, а
`ruBillingDependencies` — авторизацию, пользователя, кеш и остальные зависимости
конкретного приложения. Factory создаёт настоящий
`URLSessionRUCatalogRepository`; отдельного `HTTPRUCatalogRepository` в public
API нет. Decoder не должен читать Keychain, выполнять network request или
решать, кому доступен RU Billing.

## Неподвижные правила массива

Backend-массив является контрактом. Платформа обязана:

1. сохранить каждую строку;
2. сохранить исходный порядок;
3. сохранить повторения одного SKU;
4. вернуть 0, 1, 2 или N продуктов без скрытого лимита;
5. отклонить некорректную строку понятной ошибкой, а не потерять её молча.

Запрещены `sorted`, `filter`, `compactMap`, `prefix`, deduplication и
`Dictionary(uniqueKeysWithValues:)` на общей границе. Если конкретному
приложению нужны две карточки, оно выбирает их **после** получения полного
результата в своём UI/configuration; общий package не меняется.

## Точное сопоставление

RU product связывается с Apple/Adapty product по точному
`appStoreProductId`. Нельзя искать «похожий» продукт по цене, длительности,
названию или позиции в массиве: такое совпадение может отправить в checkout
не тот товар.

```text
com.company.app.premium.month
          │ exact equality
          ▼
premium_month_ru
```

Если точного соответствия нет, RU method для этого продукта недоступен и UI
показывает безопасную ошибку/Apple-only состояние согласно app policy.

## Что связано с `ru_pay`, а что нет

Каталог сам по себе ничего не включает. СБП/карта показываются только когда
одновременно выполнены все условия:

```text
host configured
AND verified-fresh ru_pay = true
AND (Storefront RU/RUS OR iPhone region RU/RUS)
AND non-empty exact catalog match
AND backend authorization/kill switch
AND premium is not already active
```

Отсутствующий, `false` или некорректный `ru_pay` закрывает RU methods. Русский
язык не является региональным сигналом. Перед созданием checkout Storefront
читается повторно, поэтому устаревшее состояние не авторизует платёж.

## Минимальная проверка без настоящей оплаты

- 0, 1, 2 и 20+ продуктов;
- дубли SKU и provider order;
- camelCase и snake_case IDs;
- отсутствующее обязательное поле;
- неизвестный payment method;
- цена в согласованной единице;
- точный match и deliberate mismatch;
- timeout/offline;
- `ru_pay` absent/false/invalid/verified true;
- Storefront RU при non-RU регионе;
- RU регион при недоступном/non-RU Storefront;
- русский язык при двух non-RU сигналах — Apple only.

Настоящий purchase, restore или RU-платёж platform gate не выполняет.

## Где сверять актуальность

- [Полный RU Billing contract](RUBilling.md)
- [Монетизация целиком](Monetization.md)
- [Integration Plan](Templates/AppIntegrationPlan.md)
- обезличенный fixture:
  `Examples/BroadAppTemplate/Fixtures/ru-catalog-flat.json`

Целевое правило платформы зафиксировано **30 августа 2026 года**. Конкретное
приложение могло ещё не обновиться; перед его изменением сравните фактический
код с этой инструкцией и подтвердите rollout у team lead.
