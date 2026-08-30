# RU Billing: российские способы оплаты

RU Billing — опциональная цепочка адаптеров для СБП и банковской карты. Она
включается, только если одновременно выполнены три условия:

1. приложение само включило feature;
2. host-controlled verified-fresh remote payload вернул `ru_pay = true`;
3. App Store Storefront равен `RU/RUS` **или** регион iPhone равен `RU/RUS`.

В третьем условии достаточно одного совпадения. Язык приложения, первый
системный язык, клавиатура, IP и timezone не участвуют. Если `ru_pay`
отсутствует, равен `false`, повреждён либо payload не имеет
`.verifiedFreshRemote`, СБП и карта скрыты даже при российском Storefront или
регионе iPhone. Приложение никогда не подставляет `true` автоматически.

> [!IMPORTANT]
> Это целевое правило платформы с 30 августа 2026 года. Конкретное приложение
> могло ещё не перейти на него. Перед релизом зафиксируйте фактическую реализацию
> вместе с тимлидом в `AppIntegrationPlan`.

> `ru_pay` разрешает только показать и открыть RU-способ оплаты. Он не
> подтверждает оплату и не открывает premium. После checkout платформа ждёт
> backend status и запускает новый authoritative entitlement refresh; только
> итоговый `active` выдаёт доступ.

Спешл оффер с Apple/СБП/картой использует тот же RU Billing transport и
entitlement refresh, но имеет отдельные campaign и timer decisions. Не
переносите их из Adapty Special Offer или одного reference app. Полная
инструкция: [Спешл оффер RU Billing](RUSpecialOffer.md).

## Главное правило `ru_pay`

`ru_pay` — это флаг Adapty, а не локальная настройка приложения.

| Режим | Источник `ru_pay` | Назначение |
|---|---|---|
| Release | Verified-fresh remote payload | Production |
| Debug · `Как в Adapty` | Тот же strict provenance gate | Интеграционная проверка |
| Debug · `Включить` / `Выключить` | Process-local override | Проверка UI и gate-веток |

Новый проект без RU Billing начинает с `false`. Если feature уже
подключена и должна работать, её согласованное значение в Adapty может
быть `true`; не перезаписывайте его шаблонным JSON. Удаление приложения из
App Store не переключает Adapty Remote Config автоматически. Для
экстренного отключения нужны управляемый `ru_pay = false` и backend
kill switch; backend в любом случае остаётся финальной финансовой authority.

## Что уже делает пакет

Приложение передаёт адреса API, авторизацию, сопоставление продуктов и,
если формат API отличается, свои encoder/decoder.
Всё остальное делает платформа:

```text
ru_pay + (Storefront RU или регион iPhone RU) → сопоставление каталога → экран оплаты → платёжная ссылка
→ постоянная pending-запись → возврат и проверка → обновление entitlement → настройки подписки
```

| App Store | СБП/карта | Настройки |
|---|---|---|
| RU-поля скрыты, кнопка запускает Apple purchase | две обязательные галочки, опциональный чек и email | тариф, статус, дата оплаченного доступа и отмена |

<p align="center">
  <img src="Assets/README/Screenshots/ru-payment-methods-v3.png" alt="Выбор App Store, СБП или карты без отдельных legal-ссылок" width="23%">
  <img src="Assets/README/Screenshots/ru-payment-receipt-dark.png" alt="Отдельный ввод email для чека" width="23%">
  <img src="Assets/README/Screenshots/ru-subscription-active-dark.png" alt="Активная RU подписка" width="23%">
  <img src="Assets/README/Screenshots/ru-subscription-cancelled-dark.png" alt="RU подписка после отмены" width="23%">
</p>

Это реальные скриншоты `BroadAppTemplate` из iPhone Simulator, а не макеты.

## Восстановление после переустановки

RU-подписка и RU-токены принадлежат серверному пользователю, а не конкретной установке
приложения. После восстановления входа приложение обязано создать тот же fingerprinted
`EntitlementSubject`, новую актуальную привязку авторизации и вызвать
`RecoverCustomerAccessUseCase`.

- RU premium возвращается через общую entitlement-проверку с источником `.ruBilling`;
- тариф, дату оплаченного доступа и статус автопродления возвращает
  `loadSubscriptionStatus`;
- RU-токены возвращает полный backend balance snapshot авторизованного app
  account; checkout ID нужен только серверу для однократного начисления;
- email для чека может исчезнуть после удаления: это только настройка формы, а не ID
  пользователя и не доказательство покупки.

Не используйте Storefront, регион устройства, системный язык, device ID или email из чека
для поиска уже совершённой покупки. Финансовое решение использует Storefront и
регион, а язык отвечает только за локализацию. Без
стабильного app account гарантированное восстановление RU-покупок невозможно.
[Полный порядок →](AccountRecovery.md).

Если сеть исчезла после открытия платёжной ссылки, pending session не очищается и
новый checkout автоматически не создаётся. При возврате `applicationDidBecomeActive()`
получит типизированный `offline`/`timeout`, остановит polling и оставит возможность безопасно
повторить только проверку статуса. [Все сценарии обрыва сети →](NetworkInterruptions.md).

## Экран оплаты: что передаёт приложение

```swift
let ruPresentation = BroadRUBillingPresentationConfiguration()

let paywallConfiguration = BroadPaywallConfiguration(
    placementID: .settings,
    copy: .russian,
    legalLinks: appStoreLegalLinks,
    ruBilling: ruPresentation
)
```

Важно: окно выбора способа оплаты **не показывает отдельные ссылки**
«Политика конфиденциальности» и «Публичная оферта». Это компактный экран
с тремя способами оплаты и галочками согласия. Обычные ссылки «Политика» и
«Условия» задаются в `BroadPaywallConfiguration.legalLinks` и остаются в подвале
самого paywall.

Для СБП и банковской карты `BroadPaymentMethodSheet` не разрешит продолжить оплату, пока
пользователь не выполнит обязательные действия:

1. согласие с офертой и обработкой персональных данных;
2. для автоматически продлеваемой подписки — согласие на регулярные списания. В тексте
   обязательно показываются настоящая цена и период выбранного продукта;
3. если пользователь запросил чек — корректный email на отдельном втором шаге.

Экран сначала показывает способы оплаты и обязательные согласия. Поле email не
занимает место в этом списке: оно появляется только после нажатия «Продолжить» и
только если пользователь включил получение чека. Основная кнопка закреплена над
Home Indicator и клавиатурой, поэтому её не нужно искать прокруткой.

Чтобы пользователь не вводил email для чека каждый раз, создайте адаптер поверх уже
существующего хранилища из `BroadCore` и передайте его в paywall:

```swift
let receiptEmailStore = BroadKeyValueReceiptEmailStore(
    store: UserDefaultsKeyValueStore(
        namespace: "com.company.app.ru-billing-form"
    )
)

BroadPaywallView(
    viewModel: paywallViewModel,
    receiptEmailStore: receiptEmailStore,
    onClose: close,
    onCompleted: complete
)
```

Адрес хранится по ключу `receiptEmailStorageKey`, который задаёт приложение. Если хранилище
не передано, форма просто не запоминает email. Адрес никогда не попадает в аналитику или логи.
При оплате через Apple все RU-поля скрыты. Отдельного переключателя «включить автопродление»
нет: согласие на регулярное списание — обязательное условие конкретной RU-оплаты.

Даже если доступен только один RU-способ оплаты, пакет всё равно открывает этот экран с
согласиями. Единственный Apple-способ можно запустить сразу. Все интерактивные элементы
используют `BroadNoPressEffectButtonStyle`: при нажатии нет затемнения, уменьшения или
мерцания.

<a id="safe-disabled-composition"></a>
## Как отключить RU Billing

Если приложение не использует RU Billing, не создавайте фиктивные URL, токены или
вечно неопределённый entitlement-источник. Передайте готовые disabled-адаптеры:

```swift
let checkoutMethods: any ResolveCheckoutMethodsUseCaseProtocol =
    DisabledRUBillingCheckoutMethodsUseCase()
let startSelectedRU: any StartSelectedRUCheckoutUseCaseProtocol =
    DisabledSelectedRUCheckoutUseCase()

let catalog: any RUCatalogRepositoryProtocol = DisabledRUCatalogRepository()
let subscription: any RUSubscriptionRepositoryProtocol =
    DisabledRUSubscriptionRepository()
```

`BroadMonetizationServices` по умолчанию уже даёт
`CheckoutSelectedProductUseCaseProtocol`, который работает только с Apple. Для App Store-only
приложения не нужны RU assembly, endpoint и фиктивный catalog.

> [!IMPORTANT]
> Когда RU Billing выключен, не добавляйте `.ruBilling`-регистрацию в Entitlement Engine.
> Engine должен содержать только те источники, которые приложение реально умеет
> проверить.

<a id="device-context"></a>
## Как проверяются Storefront и регион iPhone

`SystemRUBillingDeviceContextProvider` читает только регион iPhone:

```swift
let context = RUBillingDeviceContext(
    regionCode: Locale.current.region?.identifier
)
```

`context.isRussian` становится `true` только для `RU/RUS`. Текущий Storefront
загружает `StorefrontRepositoryProtocol`. `RUBillingGate` разрешает региональную
часть условия, когда российским является хотя бы один из этих двух сигналов.
Русский язык при двух нероссийских сигналах ничего не включает.

Проверка выполняется в двух местах:

1. `ResolveCheckoutMethodsUseCase` — до показа пользователю СБП и карты;
2. `RUCheckoutFlowCoordinator` — повторно загружает текущий Storefront перед
   созданием внешней оплаты.

Для воспроизводимого fixture-сценария можно передать свой
`RUBillingDeviceContextProviderProtocol`; production composition по умолчанию
использует системный provider.

```swift
let storefrontRepository = CachedStorefrontRepository(
    cache: cache,
    cacheTimeToLive: 24 * 60 * 60
)
```

Безопасная настройка по умолчанию:

```swift
let checkoutMethods = ResolveCheckoutMethodsUseCase(
    storefrontRepository: storefrontRepository,
    catalogRepository: catalogRepository,
    isFeatureEnabled: true
)
```

`RemoteRUBillingGateDecision` имеет четыре состояния:

- `.absent` — поля `ru_pay` в remote config нет;
- `.enabled` — все найденные aliases имеют значение `true`;
- `.disabled` — хотя бы один alias имеет `false`;
- `.invalid` — данные повреждены или противоречат друг другу.

`.absent`, `.disabled` и `.invalid` всегда закрывают RU Billing. `.enabled`
разрешает показать RU methods только для `.verifiedFreshRemote`, если также
совпал российский Storefront либо регион iPhone. Значение из
`.providerCacheFallbackPossible`, `.platformCache` или legacy payload не даёт этого
разрешения.

## Offline fallback Adapty не авторизует RU Billing

Fallback JSON из Adapty Dashboard можно добавить в app bundle для обычного
paywall и Special Offer:

```swift
guard let fallbackURL = Bundle.main.url(
    forResource: "adapty_fallback",
    withExtension: "json"
) else {
    preconditionFailure("Adapty fallback is configured but missing from the bundle")
}

let configuration = AdaptyPlatformConfiguration(
    apiKey: runtimeConfiguration.adaptyKey,
    accessLevelID: runtimeConfiguration.premiumAccessLevel,
    subject: entitlementSubject,
    fallbackFileURL: fallbackURL
)
```

Платформа вызывает `Adapty.setFallback(fileURL:)` до первой activation.
Файл остаётся Adapty-owned payload, но его provenance
`.providerCacheFallbackPossible` не доказывает свежесть `ru_pay`.
[Официальная инструкция Adapty по fallback paywalls](https://adapty.io/docs/ios-use-fallback-paywalls).

Fixture `-ru-pay-adapty-fallback-rejected` проверяет эту fail-closed
границу. Host, которому нужен RU Billing в Release, обязан собрать
`LoadPaywallUseCase` с host-controlled `PaywallRepositoryProtocol`, который доказывает
network origin и ставит `.verifiedFreshRemote`; стандартная Adapty factory такую
инъекцию не даёт.

## Debug-переключатель

Для UI/gate-проверок Debug-сборка имеет `.followAdapty`, `.forceEnabled`
и `.forceDisabled`. Host template создаёт store с
`allowsManualOverrides: true` только из своего `#if DEBUG`;
обычный initializer всегда принудительно возвращает `.followAdapty`. Это
работает и для именованных Debug Xcode configurations, когда Swift Package
и host target могут по-разному видеть compilation condition.

Переключение живёт в текущем процессе, не меняет Adapty и не
попадает в Release UI/composition.

Один `RUBillingDebugOverrideStore` передаётся в Debug UI и
`RUBillingCompositionDependencies`. Так resolver и финальная проверка перед
checkout видят одно решение. Force-on заменяет только remote-флаг и не
обходит:

- `isFeatureEnabled` в composition;
- App Store Storefront/регион iPhone;
- наличие и точное сопоставление backend catalog;
- backend authorization и финальный entitlement refresh.

Поэтому Debug force-on не симулирует успешную production-оплату.

### Что искать в Console

`ResolveCheckoutMethodsUseCase` пишет typed-событие
`ru-billing.availability.evaluated` только с закрытой причиной и числом
доступных методов. Raw Remote Config, product ID, URL, email и token не
логируются.

| Причина | Что проверить |
|---|---|
| `available` | Adapty, Storefront/регион iPhone и catalog разрешили RU methods |
| `remote-flag-absent/disabled/invalid` | Payload текущего resolved paywall в Adapty |
| `unqualified-remote-configuration` | Данные пришли из platform/legacy cache, а не provider payload |
| `device-context-not-russian` | Текущий Storefront и регион iPhone; язык не участвует |
| `catalog-unavailable/product-not-matched/methods-unavailable` | Backend catalog и exact mapping |
| `debug-forced-enabled/disabled` | Текущий process-local Debug-режим |

<a id="http-configuration-and-authorization"></a>
## Настройка HTTP и авторизации

В package нет зашитых production host, application ID, endpoint path или токена. Всё это передаёт
конкретное приложение:

```swift
let configuration = RUBillingHTTPConfiguration(
    baseURL: URL(string: "https://payments.example.com")!,
    applicationID: AppIdentity.paymentApplicationID,
    appBundleIdentifier: AppIdentity.bundleIdentifier,
    endpoints: RUBillingEndpointConfiguration(
        catalog: RUBillingEndpointPath(rawValue: "/v1/catalog"),
        checkout: RUBillingEndpointPath(rawValue: "/v1/checkout"),
        paymentStatus: RUBillingEndpointPath(rawValue: "/v1/payment/status"),
        entitlementStatus: RUBillingEndpointPath(rawValue: "/v1/subscription/status"),
        cancellation: RUBillingEndpointPath(rawValue: "/v1/subscription/cancel")
    )
)
```

Каждый URL обязан использовать HTTPS. Redirect, логин/пароль в URL, cookie, URL cache и ответ без
ограничения размера отклоняются. Авторизацию даёт `SubjectAuthorizationProviderProtocol`. Bearer-значение:

- привязано к конкретному subject;
- живёт только в памяти;
- скрыто даже при reflection;
- не пишется в лог и хранилище.

После сетевого `await` успешный ответ принимается, только если provider всё ещё возвращает
ту же credential для того же subject. Logout, смена аккаунта или ротация токена делают старый ответ
недоступным.

<a id="enabled-composition-in-two-steps"></a>
## Подключение RU Billing в два шага

`RUBillingCompositionFactory` создаёт production-адаптеры. Два шага нужны, чтобы не получилась
циклическая зависимость:

1. сначала RU-регистрация добавляется в общий Entitlement Engine;
2. затем готовый engine передаётся в polling и cancellation use cases.

```swift
// Один экземпляр живёт всё время работы приложения.
let authorizationSession = SubjectAuthorizationSession()
let authorizationBinding = authorizationSession.begin(for: entitlementSubject)

let ruFactory = RUBillingCompositionFactory(
    configuration: RUBillingCompositionConfiguration(
        http: configuration,
        entitlementFreshness: ruFreshnessPolicy,
        isFeatureEnabled: true
    ),
    dependencies: RUBillingCompositionDependencies(
        subject: entitlementSubject,
        applicationIdentifier: AppIdentity.bundleIdentifier,
        authorizationProvider: appSessionAuthorizationProvider,
        authorizationBinding: authorizationBinding,
        cache: cache,
        analytics: analytics,
        productMappingPolicy: ExactOnlyRUCatalogProductMappingPolicy()
    )
)

let ruRegistration = ruFactory.makeEntitlementRegistration()

let entitlementEngine = EntitlementEngine(
    registrations: appleAndBackendRegistrations + [ruRegistration],
    subject: entitlementSubject,
    cache: entitlementCache,
    timeoutPolicy: entitlementTimeout
)

let ru = ruFactory.makeServices(
    refreshEntitlement: entitlementEngine,
    operationGate: monetizationServices.operationGate
)
```

При каждой смене пользователя новый набор зависимостей сначала вызывает
`authorizationSession.begin(for:)` на том же общем экземпляре `SubjectAuthorizationSession`. Это
сразу отзывает привязки старых незавершённых задач, даже если старый provider всё ещё
возвращает прежний токен. При logout без нового аккаунта вызовите `authorizationSession.invalidate()`.
Одновременный logout не приведёт к crash: HTTP- и checkout-границы просто отклонят уже неактуальную
привязку.

Готовый `RUBillingServices` даёт два небольших набора:

- `catalog.repository`, `catalog.resolveProduct`,
  `catalog.resolveCheckoutMethods`;
- `checkout.startSelectedProduct`, `checkout.applicationReturn`,
  `checkout.cancelSubscription`, `checkout.operationGate`.

Создание raw backend-session, polling статуса и их repository остаются внутри модуля.
Приложение не может обойти точное сопоставление каталога, проверку `ru_pay` и
контекста iPhone,
владение pending-записью или проверку subject после возврата.

> [!IMPORTANT]
> В `RUBillingCompositionFactory.makeServices` обязательно передайте тот же
> `monetizationServices.operationGate`, который уже используют Apple purchase/restore. Не создавайте
> второй gate для RU Billing или нового аккаунта.

Один общий gate гарантирует, что pending RU-оплата блокирует новый Apple purchase/restore, а
незавершённая Apple-операция блокирует новую RU backend-session.

`applicationIdentifier` — стабильный неперсональный ID приложения, обычно bundle ID. Pending-хранилище
использует один ключ на application ID, но в записи сохраняет subject, который начал оплату.
Новый аккаунт видит только непрозрачный блокер. Он не получает ID сессии или попытки и не может
проверить или очистить чужую backend-session.

Если приложение использует Swinject-сборки платформы, добавьте `RUBillingAssembly(services:)`
после `BroadMonetizationAssembly`. Сборка заменит Apple-only регистрацию
`CheckoutSelectedProductUseCaseProtocol` на общий Apple/RU router и зарегистрирует узкие RU-протоколы.

Для backend с другим форматом передайте `RUBillingWireAdapters` и замените только нужные пары
request/response. Если после миграции нужно проверять несколько источников статуса, передайте
дополнительные authoritative clients в `RUBillingCompositionDependencies`.

<a id="wire-contracts"></a>
## Контракты HTTP-запросов и ответов

Пути endpoint и HTTP-методы настраиваются, а backend payload остаётся на границе Infrastructure.
Для catalog, checkout, payment status, cancellation и entitlement есть отдельные request/response-контракты.

`BroadAppsRUBillingWireContract` и `BroadAppsRUCatalogResponseDecoder` реализуют готовую схему ниже.
Если backend возвращает другой JSON, замените только нужные протоколы, например
`RUCheckoutRequestEncoderProtocol` и `RUCheckoutResponseDecoderProtocol`. Менять Domain или UI не нужно.

Для распространённого плоского каталога `{ "products": [...] }` платформа
также предоставляет `FlatRUCatalogResponseDecoder` и короткую композицию
`RUBillingWireAdapters.broadAppsFlatCatalog(supportedMethods:)`.

Стандартный checkout-запрос добавляет `customerEmail` только когда пользователь сам запросил
чек. UI может запомнить адрес по app-configurable ключу, но body запроса не хранится и не логируется.
Другому backend достаточно заменить checkout encoder.

### Готовая JSON-схема BroadApps

Ниже — полный контракт `BroadAppsRUBillingWireContract` и `BroadAppsRUCatalogResponseDecoder`.
Все запросы авторизуются в HTTP client временным значением, привязанным к subject. JSON-ключи
имеют формат `snake_case`, даты — ISO-8601 с дробными секундами или без них. Endpoint path по-прежнему
задаёт приложение.

#### Каталог

```http
GET <catalog-path>?app_id=<application-id>&app_bundle=<bundle-id>
```

Предпочтительный ответ хранит массив в `products`:

```json
{
  "products": [
    {
      "product_id": "<backend-product-id>",
      "kind": "subscription",
      "app_store_product_id": "<apple-sku>",
      "price": {
        "amount": 499,
        "currency_code": "RUB"
      },
      "display_price": "499 ₽",
      "subscription_period": {
        "unit": "month",
        "count": 1
      },
      "payment_methods": ["sbp", "card"]
    }
  ]
}
```

Декодер также принимает массив в корне JSON или объект, разделённый по категориям:

```json
{
  "subscriptions": [],
  "tokens": [],
  "coupons": []
}
```

Название секции жёстко задаёт `kind`. В плоском ответе `kind` принимает `subscription`, `tokens`,
`coupon` и `unknown`; если `kind` нет, получается `unknown`. Поля `app_store_product_id`, `price`,
`display_price` и `subscription_period` опциональны. Единица периода: `day`, `week`, `month`, `year`
или своя непустая строка. Неизвестные способы оплаты игнорируются. Готовый premium checkout
понимает только `sbp` и `card`.

#### Текущий плоский каталог backend

Приложения могут получать подписки и токены одним авторизованным запросом:

```http
GET <catalog-path>
Authorization: Bearer <current-app-session>
```

```json
{
  "products": [
    {
      "productId": "premium_month",
      "title": "Premium на месяц",
      "kind": "subscription",
      "period": "month",
      "price": 499,
      "currency": "RUB",
      "credits": null
    }
  ]
}
```

Подключение:

```swift
let wire = RUBillingWireAdapters.broadAppsFlatCatalog(
    supportedMethods: [.sbp, .card]
)
```

`supportedMethods` задаётся явно, потому что старый плоский ответ не всегда
содержит способы оплаты. `price` считается суммой в основных единицах валюты.
Если backend отдаёт копейки, другую envelope-модель или отдельные endpoints,
нужен собственный decoder. Не угадывайте единицу цены.

Decoder принимает camelCase и snake_case product IDs, сохраняет title, credits,
порядок и каждое повторение. Он не сортирует, не ограничивает список двумя
строками и не превращает массив в dictionary.

#### Создание checkout

```http
POST <checkout-path>
Content-Type: application/json
```

```json
{
  "product_id": "<backend-product-id>",
  "payment_method": "sbp",
  "accepts_auto_renewal": true,
  "customer_email": "developer@example.com",
  "app_id": "<application-id>",
  "app_bundle": "<bundle-id>"
}
```

```json
{
  "checkout_session_id": "<opaque-session-id>",
  "payment_url": "<ephemeral-https-payment-url>",
  "expires_at": "2030-01-02T03:04:05Z"
}
```

`payment_method` может быть только `sbp` или `card`. Поле `customer_email` опционально:
оно отправляется, только если пользователь сам запросил чек. Пакет никогда не придумывает
email за пользователя. Поле `expires_at` тоже опционально.

Ответ отклоняется, если ID сессии некорректен или `payment_url` не является безопасным
HTTPS-адресом с указанным host. Логин и пароль внутри URL запрещены. Платёжная ссылка живёт
только в памяти и никогда не сохраняется в pending-кеш.

#### Статус оплаты

```http
POST <payment-status-path>
Content-Type: application/json
```

```json
{
  "checkout_session_id": "<opaque-session-id>",
  "app_id": "<application-id>",
  "app_bundle": "<bundle-id>"
}
```

```json
{
  "checkout_session_id": "<opaque-session-id>",
  "status": "pending"
}
```

Поле `status` принимает только `pending`, `paid`, `failed`, `cancelled` или `expired`.
ID сессии в ответе должен точно совпасть с запрошенным ID. Даже статус `paid` не открывает
доступ напрямую: он только запускает общую авторитетную проверку entitlement.

#### Отмена подписки

```http
POST <cancellation-path>
Content-Type: application/json
```

```json
{
  "subscription_id": "<backend-subscription-id>",
  "app_id": "<application-id>",
  "app_bundle": "<bundle-id>"
}
```

```json
{
  "status": "cancelled",
  "effective_until": "2030-01-02T03:04:05Z"
}
```

Поле `status` принимает `cancelled`, `already_inactive` или `failed`.
Поле `effective_until` опционально. Старый endpoint, если он нужен приложению, использует
такой же формат. Он вызывается только после явного включения legacy fallback.

#### Проверка доступа

```http
GET <entitlement-status-path>?app_id=<application-id>&app_bundle=<bundle-id>
```

```json
{
  "subscription_active": true,
  "subscription_expires_at": "2030-01-02T03:04:05Z",
  "subscription_lifetime": false
}
```

`subscription_expires_at` и `subscription_lifetime` опциональны. Если флага lifetime нет,
его значение считается равным `false`. Личность пользователя никогда не берётся из этого
JSON. Она приходит из уже авторизованной композиции и добавляется локально после декодирования.
Ошибки сети, авторизации, типов, дат или противоречивые данные дают `unresolved`, а не
ложный `inactive`.

Не меняйте эти payload только на одной стороне. Если backend использует другой JSON,
приложение обязано передать соответствующую пару encoder/decoder и отдельно описать свой
контракт.

<a id="catalog-and-matching"></a>
## Каталог и сопоставление продуктов

Каждая строка каталога имеет явный `RUCatalogProductKind`:

- `subscription`;
- `tokens`;
- `coupon`;
- `unknown`.

`RUCatalogSections` не смешивает эти категории. `RUCatalogProductMatcher` ищет продукт
в строго определённом порядке:

1. точное совпадение с учётом регистра по backend product ID или связанному App Store ID;
2. точный backend ID, который вернула явно переданная приложением политика
   `RUCatalogProductMappingPolicyProtocol`;
3. если точных совпадений несколько, побеждает первая строка в порядке backend.

По умолчанию используется `ExactOnlyRUCatalogProductMappingPolicy`. Платформа никогда не
угадывает продукт по цене или периоду и не отправляет придуманный server ID. Если у приложения
есть собственная точная таблица «SKU → backend ID», передайте
`AppOwnedRUCatalogProductMappingPolicy`. Fuzzy mapping по периоду или цене не
является допустимым платформенным контрактом.

Общий premium paywall показывает RU-оплату только для автоматически продлеваемых,
непродлеваемых и non-consumable продуктов, которые дают доступ и точно сопоставлены со строкой
`subscription`. Расходуемые продукты, наборы токенов, купоны и неизвестные продукты намеренно
исключены. Причина простая: `RefreshRUPaymentUseCase` подтверждает premium-доступ, но не начисляет
токены и не активирует купоны.

Типы каталога и read-only доступ к нему остаются публичными, поэтому приложение может построить
отдельный типизированный flow начисления токенов. Внутренние создание premium-сессии и polling
нельзя использовать как короткий путь для начисления токенов.

`CachedRUCatalogRepository` хранит последний корректный каталог в течение настроенного stale-периода.
Частичная сетевая ошибка не перезаписывает его. `RUBPriceFormatter` форматирует только настоящую
`Money(currencyCode: "RUB")`; UI никогда не придумывает цену.

<a id="checkout-external-page-and-pending-context"></a>
## Checkout, внешняя платёжная страница и pending-запись

Рабочая цепочка выглядит так:

```text
создать checkout → проверить HTTPS-ссылку → сохранить pending-запись → открыть ссылку
                 → приложение снова активно → проверить статус → обновить entitlement
```

`RUCheckoutFlowCoordinator` сохраняет только безопасный минимум: ID checkout-сессии,
созданный приложением attempt ID, ID продукта каталога, способ оплаты, конечную дату начала,
опциональный срок от backend, непрозрачный scope исходного пользователя и атрибуцию paywall
(`presentationID`, опциональную variation провайдера, requested/resolved placement).

Атрибуция остаётся только на устройстве и переживает холодный запуск. Благодаря этому события
created/returned/confirmed/timed-out относятся к тому же paywall. Она никогда не добавляется в
`RUCheckoutRequest` и не отправляется платёжному backend. Запись не хранит платёжный URL, email,
bearer-токен, сырой payload провайдера или личность пользователя.

`UIApplicationPaymentURLOpener` считает `UIApplication.open == false` ошибкой. Результат `.opened`
означает только одно: внешняя страница открылась. Он не выдаёт premium и не активирует AppFlow.

После ответа checkout авторизованный HTTP-клиент ещё раз проверяет точного пользователя и его
актуальную credential. Flow повторяет эту проверку перед сохранением pending-записи и ещё раз
после `await`, прямо перед открытием Safari.

- если аккаунт сменился до сохранения, внешняя страница не откроется;
- если аккаунт сменился во время сохранения, блокер старого пользователя намеренно остаётся,
  но страница всё равно не откроется;
- неопределённую финансовую попытку нельзя удалять только потому, что изменился login state.

`CheckoutSelectedProductUseCaseProtocol` — единая граница paywall, которая не зависит от способа
оплаты. `.apple` передаёт работу проверенному `PurchaseSelectedProductUseCaseProtocol`. `.sbp` и
`.card` вызывают `StartSelectedRUCheckoutUseCase`: он находит точный `RUCatalogProductID` выбранной
строки и запускает `RUCheckoutFlowCoordinator`. Результат `.opened` преобразуется в `.pending`,
поэтому экран показывает уведомление и не сообщает об успешной покупке раньше времени.

До открытия URL pending-запись создаётся атомарной операцией «добавить, только если её ещё нет».
Удалить её можно только операцией «сравнить и удалить» для точной пары session + attempt. Другой
аккаунт или другая композиция не могут прочитать, перезаписать или удалить эту запись. Ошибка или
повреждение хранилища дают `.unavailable` и продолжают блокировать новую финансовую операцию.
Значения TTL и `expiresAt`, сравнённые с изменяемыми часами iPhone, служат только подсказкой для UI
и разбора проблемы. Они не снимают блокировку. Сделать это может только финальный ответ backend.

Прямо перед созданием checkout координатор повторно проверяет тот же
`RUBillingGate`, загружает текущий Storefront и читает регион iPhone. Российского
значения любого из них достаточно для региональной части условия. Язык и старый
кеш Storefront не дают разрешение на оплату.
Координатор допускает только одну операцию одновременно и отклоняет новый запуск при существующей
pending-записи. Поэтому несколько одновременных нажатий не создадут две backend-сессии и не
перезапишут отслеживаемую попытку.

<a id="polling-after-return"></a>
## Проверка оплаты после возврата в приложение

После настоящего возврата приложения в активное состояние вызовите
`RUPaymentReturnCoordinator.applicationDidBecomeActive()`. Сначала координатор проверит, что
непрозрачная pending-запись принадлежит именно текущему пользователю. Затем внутренний polling
выполнит настроенное количество попыток с заданной паузой. Политика задаётся в композиции;
приложение не получает прямой доступ к низкоуровневому сервису polling:

```swift
let ruConfiguration = RUBillingCompositionConfiguration(
    http: httpConfiguration,
    entitlementFreshness: entitlementFreshness,
    isFeatureEnabled: true,
    polling: RUPaymentPollingPolicy(
        maximumAttempts: 8,
        delay: .seconds(2)
    )
)
```

Каждая попытка сначала запрашивает статус именно этой checkout-сессии. Только `.paid` запускает
новое поколение общей entitlement-проверки. Старый entitlement не может подтвердить сессию со
статусом pending, unavailable или с несовпадающим ID. Новое поколение проверяет все настроенные
авторитетные источники, включая основной backend и RU Billing. Покупка подтверждается только
свежим авторитетным результатом `active`. Оплата со статусом `paid`, но без активного entitlement,
остаётся pending. Сетевая ошибка означает unavailable, а не inactive.

Несколько одновременных foreground-callback присоединяются к одной уже выполняющейся операции
для той же попытки. Они не запускают повторные polling-циклы и не дублируют аналитику подтверждения.
Приложение всё равно само передаёт результат в AppFlow: только `.active` открывает доступ.
`.pending`, `.inactive` и `.unavailable` не разблокируют основной UI.

При холодном запуске аналитика сохраняет исходную variation paywall и оба логических placement.
Adapty сам не связывает внешнюю оплату по СБП/карте со своей конверсией. Это сопоставление делает
аналитика приложения, а variation хранится как непрозрачное значение провайдера.

Координатор возврата и paywall используют один `MonetizationOperationGate`. После финального
`.active` или `.inactive` координатор публикует изменение статуса. Уже открытый `PaywallViewModel`
заново вычисляет состояние CTA и не зависит от повторного SwiftUI `onAppear`.

<a id="cancellation-and-paid-through-access"></a>
## Отмена подписки и доступ до оплаченной даты

`BroadRUSubscriptionManagementView` — готовый экран для раздела «Настройки». Его ViewModel нужны
только два use case:

```swift
let viewModel = BroadRUSubscriptionManagementViewModel(
    dependencies: BroadRUSubscriptionDependencies(
        loadStatus: ru.checkout.loadSubscriptionStatus,
        cancelSubscription: ru.checkout.cancelSubscription
    )
)

BroadRUSubscriptionManagementView(viewModel: viewModel)
```

`LoadRUSubscriptionStatusUseCase` загружает с сервера актуальный статус именно текущего
пользователя. Готовый entitlement-ответ понимает опциональные поля `subscription_id`,
`subscription_plan_name` и `subscription_auto_renewal_cancelled`. Если API приложения имеет
другой формат, замените только entitlement decoder.

Экран сам показывает загрузку, ошибку и повтор, текущий тариф, статусы active/inactive, дату
окончания оплаченного доступа, подтверждение перед отменой и состояние после отмены. Из раздела
«Настройки» второй paywall не открывается.

`URLSessionRUCancellationRepository` работает с одним endpoint.
`RUCancellationRepositoryFactory` читает флаг
`RUBillingHTTPConfiguration.allowsLegacyCancellationFallback`. Он добавляет
`FallbackRUSubscriptionRepository`, только если флаг равен `true` и приложение явно передало
путь к старому endpoint. Скрытого legacy URL в пакете нет.

После подтверждённой отмены `CancelRUSubscriptionUseCase` заново проверяет общий entitlement.
Отмена автопродления не должна сразу закрывать уже оплаченный доступ: серверный RU-статус может
остаться active с `expiresAt` до конца оплаченного периода.

В коде приложения используйте фасад `RUBillingManager`. Он даёт четыре понятных действия: начать
оплату, обработать возврат в приложение, загрузить статус подписки и отменить её. Низкоуровневые
polling и HTTP-repository остаются внутри пакета.

<a id="ru-entitlement-source"></a>
## Источник RU-доступа

`URLSessionRUBillingEntitlementClient` принимает `active` или `inactive` только из свежего,
успешно декодированного ответа сервера для точного текущего пользователя. Ошибка сети,
авторизации или декодирования, а также противоречивые даты дают `unresolved`.

Для миграции пользователей или endpoint в `RUBillingEntitlementRepository` можно передать
несколько авторитетных clients. Любой подтверждённый active побеждает. Результат inactive
возвращается только тогда, когда каждый настроенный client явно подтвердил inactive.

```swift
let ruRegistration = RUBillingEntitlementSourceFactory(
    clients: [ruEntitlementClient],
    authorizationBinding: authorizationBinding
).makeRegistration(
    configuration: RUBillingEntitlementSourceConfiguration(
        subject: entitlementSubject,
        freshnessPolicy: ruFreshnessPolicy
    )
)
```

Эта фабрика всегда создаёт ровно одну логическую регистрацию `.ruBilling`. Добавляйте её в
`EntitlementEngine`, только когда RU backend включён и полностью настроен.

Запись RU-кеша хранит логическую эпоху авторизации текущей binding. Физический ключ кеша использует
один постоянный раздел authorization session для пары пользователь/источник, поэтому повторные
login/logout не создают бесконечное число ключей. Ответ или отложенная запись от уже отозванного
набора зависимостей могут оставить только запись старой эпохи. Новая binding точно её отклонит и
закроет доступ, а не выдаст premium по устаревшему кешу.
