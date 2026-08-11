# BroadMonetization Domain

Этот документ описывает публичный язык монетизации. Здесь нет `Adapty`, `StoreKit`,
`URLSession`, SwiftUI и backend DTO: SDK и сеть маппятся в эти модели на внешней
границе модуля.

## Три разных идентификатора продукта

Один `String` нельзя безопасно использовать сразу для UI, покупки и аналитики.
Платформа разделяет три смысла:

| Тип | Что означает | Можно ли повторять в одном paywall |
|---|---|---|
| `ProductID` | валидный SKU или fail-closed opaque surrogate для malformed provider ID | да |
| `ProductReference` | opaque-ссылка на точный provider product для покупки | да |
| `ProductPresentationID` | ID конкретной карточки в текущей выдаче | нет |

Поэтому массив из пяти продуктов остаётся массивом из пяти продуктов, даже если
два или все пять элементов имеют одинаковый SKU. `PaywallPayload`:

- сохраняет исходный порядок;
- допускает любое количество элементов, включая ноль;
- не требует уникальности `ProductID` или `ProductReference`;
- требует уникальный `ProductPresentationID` только для корректной UI-идентичности;
- не сортирует, не фильтрует и не выбирает «лучший» продукт.

`MonetizationProduct.id` равен `ProductPresentationID`, а не SKU. Поля цены,
периода, title и subtitle допускают отсутствие. Неполная metadata не является
причиной выбросить весь продукт.

Adapty `vendorProductId`, который пуст, не trimmed или превышает
identifier bound, не проходит в domain как raw string. Data adapter подставляет
bounded deterministic `adapty-opaque-unavailable-<SHA256>` и убирает `Money`.
Это сохраняет occurrence 1:1 для UI, но делает его semantic disabled и
не позволяет surrogate попасть в Apple/RU checkout или analytics selection.

## Placement и резерв на main

`PlacementID` — логический ID платформы. Есть готовые значения:

`onboarding`, `main`, `settings`, `feature`, `tokens`, `discount`, `specialOffer`

Для любого другого сценария приложение создаёт `PlacementID.custom(...)`.
Конкретный Adapty placement ID задаётся host-приложением в registry и не попадает
в UI.

`PaywallLoadRequest` всегда использует единый логический резерв `.main`:

- запрошен не `main` — после исчерпания точного placement можно попробовать `main`;
- запрошен `main` — повторного fallback нет;
- variation относится к фактически загруженному resolved paywall;
- cache ведётся раздельно по логическим placement;
- результат хранит requested placement, resolved placement и typed причину fallback.

За это отвечает `PaywallOrigin`. Аналитика получает оба placement и не выдаёт
резервный `main` за исходный запрос.

## Одна презентация — один ID

`PaywallPresentationID` создаётся заново для каждого фактического показа, в том
числе когда payload взят из cache. На него опираются:

- защита `logShowPaywall` от повтора;
- shown/closed analytics;
- выбор продукта.

`PaywallReference` и `PaywallVariationID` остаются стабильными provider-opaque
значениями загруженного paywall, но не заменяют presentation ID.

Перед повторным показом cached payload adapter вызывает
`preparedForNewPresentation()`. Метод создаёт новые paywall/product presentation
ID, но сохраняет порядок, дубли SKU, product references, provider metadata и
исходный `fetchedAt`.

## Remote config без выдуманных значений

`RemotePaywallConfiguration` содержит только typed поля:

- разрешение или запрет RU Billing;
- жёсткая или мягкая политика доступа;
- задержка перед появлением кнопки закрытия;
- вариант интерфейса;
- опциональная `SpecialOfferRemoteConfiguration`.

`nil` у обычного поля означает «значение не пришло». Data-слой может сохранить
последнее валидное значение вместо молчаливого reset. Некорректная строка или
число отбрасывается parser-ом до создания доменной модели.

Special offer устроен строже:

- host передаёт `SpecialOfferConfiguration?`;
- `nil` означает полное отсутствие feature;
- при `nil` use case не имеет права обращаться к placement, сети, cache,
  persistence или запускать timer;
- placement обязателен только у непустой host-конфигурации и не имеет скрытого
  значения по умолчанию;
- crossed price, crossed value, multiplier, period text и badge всегда optional;
- отсутствие полей не создаёт фиктивную цену, скидку, период или badge;
- отсутствие remote gate означает выключенный offer.

Состояния представлены `SpecialOfferState`: `unavailable`, `eligible`, `active`,
`expired`, `cooldown`.

Полный opt-in flow, remote gate, main fallback и persistence описаны в
[SpecialOffer.md](SpecialOffer.md).

## Purchase и restore

`ProductSelection` привязывает выбранную карточку к конкретным paywall,
presentation, variation, provider-array index и requested/resolved placement.
Product сохраняет opaque commercial fingerprint цены/периода/offer terms: cached
raw handle можно rehydrate только при exact variation + index + SKU + fingerprint
match. `PurchaseRequest` добавляет способ оплаты: `.apple`, `.sbp` или `.card`.

SDK-adapter сначала возвращает внутренний `PurchaseAttemptOutcome`:

- `completed` — provider подтвердил операцию, но entitlement ещё не проверен;
- `cancelled`;
- `pending`;
- `failed(error, disposition)` — adapter явно различает
  `definitivelyNotPurchased` и `outcomeUnknown`.

Затем purchase use case обязательно запускает entitlement refresh с
`.startNewGeneration`. Только после этого публичный `PurchaseOutcome` различает:

- `activated(snapshot)` — новый authoritative snapshot подтвердил active;
- `completed(confirmation)` — boundary для отдельного non-entitlement flow;
- `completedButUnverified` — SDK завершил покупку, но active пока не доказан;
- `cancelled` — пользователь отменил, это не техническая ошибка;
- `pending` — покупка ещё не завершена;
- `failed(AppError)` — безопасная typed ошибка.

AppFlow получает active только из `activated(snapshot)`. SDK `completed` не может
быть ошибочно принят UI за premium.

Standard generic purchase fail-before-charge отклоняет `.unknown` и `.consumable`.
UI продолжает показывать все provider rows, но token packs требуют отдельной host
composition с durable exactly-once fulfillment/ledger. Provider
`outcomeUnknown` становится durable `.pending`; user acknowledgement его не
очищает.

Restore разделён так же: `RestoreRepositoryProtocol` возвращает только сырой
`RestoreAttemptOutcome`, а restore use case после него проверяет общий entitlement.
Adapter не зависит от `EntitlementEngine`.

`RestoreOutcome` различает четыре принципиально разные ситуации:

- `restored(snapshot)` — общий entitlement refresh подтвердил active;
- `nothingFound` — все настроенные authoritative sources явно ответили inactive;
- `unavailable` — хотя бы один обязательный source не удалось проверить, поэтому
  отсутствие покупки не доказано;
- `failed` — сама restore-операция завершилась ошибкой.

## Storefront и RU billing

`Storefront.isRussian` проверяет только App Store storefront code `RU`/`RUS`.
Язык приложения, `Locale.current` и регион устройства в этом решении не участвуют.

RU billing намеренно не имеет одного большого `RUBillingRepositoryProtocol`.
Внутри модуля реализация разделена на четыре узкие границы:

| Граница | Ответственность | Видимость |
|---|---|---|
| `RUCatalogRepositoryProtocol` | получить каталог | public read-only |
| `RUCheckoutRepositoryProtocol` | создать checkout | internal |
| `RUPaymentStatusRepositoryProtocol` | проверить статус после Safari | internal |
| `RUSubscriptionRepositoryProtocol` | отменить подписку | public subject-bound |

Причина разделения проста: у этих операций разные timeout, retry, cache,
авторизация и жизненный цикл. Один repository-комбайн заставил бы каждый consumer
зависеть от методов, которые ему не нужны, и снова смешал бы каталог, Safari
polling, entitlement и cancel в одном manager. Financial raw boundaries
остаются internal: public composition позволяет только начать checkout
для exact selected product и возобновить его через subject-aware return coordinator.

`StorefrontRepositoryProtocol` и общий entitlement engine остаются отдельными.
Так недоступный RU-каталог не превращается в ложный inactive, а Apple checkout
может оставаться доступным как самостоятельный путь.

`RUCatalogProductKind` явно разделяет `subscription`, `tokens`, `coupon` и
`unknown`. Main-paywall mapping может исключить coupon по типу, не угадывая его по
product ID; backend-порядок и повторяющиеся mapping сохраняются.

## Typed analytics

`MonetizationAnalyticsEvent` покрывает load/show/close paywall, выбор продукта,
purchase, restore и RU checkout/Safari/polling. Paywall и purchase contexts
сохраняют provider-opaque `PaywallVariationID`; отдельные синтетические события
назначения и показа варианта не создаются, потому что provider attribution
владеет Adapty SDK.

Каждая операция получает новый `MonetizationAttemptID` — случайный app-local ID,
который не содержит provider transaction или user ID. Ошибка передаётся только как
`AppError.Kind` и безопасный `diagnosticCode`. RU analytics context намеренно не
содержит email, payment URL, checkout session ID, bearer или user identity.

`purchaseSuccess` generic premium flow отправляет только после
`PurchaseOutcome.activated`; `.completed` может быть success лишь у отдельного
verified fulfillment adapter. Для завершённой SDK-покупки без подтверждённого
entitlement существует отдельное `purchaseCompletedButUnverified`.

Композиция analytics, typed trackers, дедупликация и Adapty-owned
cross-placement attribution описаны в [Experiments.md](Experiments.md).

## Публичные use-case границы

Domain задаёт протоколы для:

- activation;
- загрузки paywall с общей main-fallback policy;
- выбора карточки по `ProductPresentationID`;
- purchase и restore;
- определения доступных checkout methods;
- RU checkout для exact selected product, subject-aware return после Safari и cancel;
- shown/closed analytics;
- optional special-offer resolution.

ViewModel зависит от этих протоколов. View получает уже готовую ViewModel через
`init` и не создаёт repository/use case самостоятельно.

## Граница зависимостей

В `Sources/BroadMonetization/Domain` допустимы только стандартная библиотека,
`Foundation` и общие безопасные типы `BroadCore`, например `AppError`.

Запрещены:

- `SwiftUI`;
- `Adapty`;
- `StoreKit`;
- `URLSession` и HTTP DTO;
- raw SDK errors;
- bearer token, payment payload и персональные данные.
