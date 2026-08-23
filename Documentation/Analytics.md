# Monetization analytics

`BroadMonetization` даёт приложению один typed-контракт для аналитики paywall,
Apple purchase/restore, entitlement и RU checkout. Он не принимает
произвольные словари, raw SDK payload или пользовательские данные.

Главная схема:

```text
paywall / purchase / restore / entitlement / RU use cases
                         ↓
            один shared analytics instance
                         ↓
        NonBlockingMonetizationAnalytics
                         ↓ bounded ordered queue
        DeduplicatingMonetizationAnalytics
                         ↓
        CompositeMonetizationAnalytics
             ↙ app analytics  ↘ attribution
```

Analytics является best-effort наблюдением. Ошибка, задержка или переполнение
очереди не меняют результат оплаты, entitlement и навигацию.

## Два независимых канала

Не смешивайте provider lifecycle и продуктовую аналитику приложения.

| Канал | API | Что делает |
|---|---|---|
| Adapty provider lifecycle | `AdaptyPaywallPresentationLifecycle` | Передаёт exact raw paywall в `Adapty.logShowPaywall` и освобождает raw handles после закрытия |
| App analytics | `MonetizationAnalyticsProtocol` | Отправляет typed события в выбранные приложением destinations |

`AdaptyPaywallPresentationLifecycle` не является analytics destination.
`TrackPaywallEventUseCase` вызывает оба канала: сначала provider lifecycle для
show/close, затем shared app analytics.

Для одного `PaywallPresentationID` Adapty lifecycle делает не более одной
локальной попытки show. Это не обещание доставки: SDK или сеть могут не принять
вызов, а у platform-cache payload может не быть raw Adapty handle.

## Production composition root

Приложение создаёт pipeline один раз и передаёт **тот же экземпляр** во все
monetization services, `EntitlementEngine`, RU assembly и paywall tracking:

```swift
let fanOut = CompositeMonetizationAnalytics(
    destinations: [
        AppProductAnalytics(),
        AppAttributionAnalytics()
    ]
)

let analytics = NonBlockingMonetizationAnalytics(
    destination: DeduplicatingMonetizationAnalytics(
        destination: fanOut
    )
)
```

Порядок обёрток важен:

1. outer `NonBlockingMonetizationAnalytics` быстро принимает событие и сохраняет
   единый порядок;
2. `DeduplicatingMonetizationAnalytics` резервирует lifecycle key до первого
   downstream `await`;
3. `CompositeMonetizationAnalytics` отправляет уже очищенное событие каждому
   destination.

Не создавайте отдельную очередь или deduplicator внутри каждого use case: так
исчезает общая граница порядка и повторное событие может пройти через другой
экземпляр.

Встроенные use cases применяют
`NonBlockingMonetizationAnalytics.wrapping(_:)`. Если им передан уже собранный
`NonBlockingMonetizationAnalytics`, новый wrapper не создаётся.

## События и обязательные поля

Все идентификаторы typed. `attemptID` связывает один запуск операции, а
`presentationID` — одно конкретное отображение paywall или occurrence продукта.

| События | Контекст |
|---|---|
| `paywallLoadStarted` | attempt, requested placement, configured main fallback |
| `paywallLoadSuccess` | load context + presentation, paywall reference, variation, requested/resolved placement, fallback reason, product count |
| `paywallLoadFailed` | load context + safe error kind/diagnostic code |
| `paywallShown`, `paywallClosed` | полный paywall context; close дополнительно несёт typed reason |
| `productSelected` | полный paywall context + product occurrence presentation ID + SKU/product ID |
| `purchaseStarted` и все purchase outcomes | attempt, paywall presentation/variation, requested/resolved placement, product occurrence, SKU, checkout method |
| `purchaseFailed` | purchase context + safe error kind/diagnostic code |
| `restoreStarted` и restore outcomes | новый attempt для каждого restore; unavailable дополнительно несёт safe failure |
| `entitlementResolved` | attempt, итоговые state/freshness и typed state/freshness каждого authority source |
| все `ruCheckout...` | attempt, RU catalog product, SBP/Card, optional полный paywall origin и variation |
| `ruCheckoutOpenFailed` | RU context + safe error kind/diagnostic code |

`productSelected` сохраняет два разных ID:

- `ProductPresentationID` отличает одинаковые SKU, пришедшие несколько раз;
- `ProductID` связывает выбор с каталогом приложения.

Это важно для payload вроде `[A, B, A]`: платформа ничего не фильтрует и
аналитика не склеивает первое и третье вхождение.

## Placement fallback и experiments

При fallback аналитика не выдаёт резервный paywall за исходный:

```text
requestedPlacementID = placement, который запросил экран
resolvedPlacementID  = placement, который реально дал payload
variationID          = variation фактического resolved paywall
fallbackReason       = причина fallback
```

Adapty остаётся единственным assignment authority для обычных и
cross-placement experiments. Платформа не создаёт synthetic assignment/show
events и не интерпретирует `variationID`. Один opaque `PaywallVariationID`
проходит из Adapty payload в show, selection, Apple purchase и RU conversion.

`uiVariantID` из remote config относится только к renderer и не является
experiment cohort.

[Полный contract экспериментов →](Experiments.md)

## Deduplication contract

`DeduplicatingMonetizationAnalytics` подавляет только события, для которых
платформа владеет устойчивым lifecycle key:

- один `paywallShown` на `PaywallPresentationID`;
- по одному событию каждого purchase lifecycle-типа на `attemptID`;
- один `entitlementResolved` на `attemptID`.

Разные outcomes имеют разные ключи. Например, `purchasePending`, а затем
`purchaseSuccess` для одного durable attempt являются двумя полезными событиями
и оба проходят.

Глобальный deduplicator намеренно не подавляет load, close, selection, restore и
RU events:

- каждый load/restore получает новый attempt;
- повторный выбор продукта может быть осмысленным действием пользователя;
- RU coordinators владеют собственным terminal/cold-launch lifecycle;
- show/close должен приходить из одного владельца presentation lifecycle.

Host не должен одновременно вручную логировать событие и вызывать platform use
case, который уже его логирует.

Deduplication хранит ограниченное число ключей, по умолчанию 2048. Это защита от
случайных concurrent дублей, а не долговременное хранилище exactly-once
доставки.

## Очередь и delivery semantics

`NonBlockingMonetizationAnalytics`:

- сериализует события в порядке приёма;
- возвращает управление финансовой/navigation операции после enqueue;
- не позволяет медленному destination задержать paywall или purchase;
- хранит не более 2048 ожидающих событий по умолчанию;
- при переполнении удаляет самое старое событие;
- не сохраняет очередь между запусками;
- не обещает flush при завершении процесса.

Если продукту нужна durable гарантированная доставка, её реализует app-owned
destination после privacy/security review. Платформа не должна ради аналитики
удерживать purchase result или выдачу подтверждённого доступа.

`CompositeMonetizationAnalytics` вызывает destinations последовательно. Каждый
destination обязан сам обрабатывать provider/network ошибки внутри `track` и не
выбрасывать raw данные наружу.

## Privacy allow-list

Разрешены только поля, уже присутствующие в typed
`MonetizationAnalyticsEvent`:

- app-generated attempt/presentation IDs;
- logical placement и catalog product IDs;
- opaque Adapty variation ID;
- typed checkout method, state, freshness, source и close reason;
- product count;
- безопасные `AppError.Kind` и `diagnosticCode`.

Запрещено добавлять в event или destination metadata:

- email, телефон, имя или raw customer/user ID;
- receipt, transaction payload или provider profile;
- bearer/API key, authorization header;
- checkout/payment/cancel URL;
- RU checkout session ID;
- raw `Error`, `localizedDescription`, response body;
- произвольный remote-config/SDK payload;
- commercial fingerprint продукта.

Product/placement ID могут раскрывать внутреннюю структуру каталога. Host
назначает им собственную retention policy и не должен кодировать в них PII.

[Общий privacy contract →](Security.md)

## Как написать destination приложения

Адаптер делает исчерпывающий `switch` по typed enum и переводит только
разрешённые поля в фиксированную схему конкретного analytics provider:

```swift
actor AppProductAnalytics: MonetizationAnalyticsProtocol {
    func track(_ event: MonetizationAnalyticsEvent) async {
        switch event {
        case let .paywallShown(context):
            await sendPaywallShown(
                requested: context.requestedPlacementID,
                resolved: context.resolvedPlacementID,
                variation: context.variationID
            )

        case let .productSelected(_, product):
            await sendProductSelected(
                occurrence: product.presentationID,
                productID: product.productID
            )

        // Остальные cases маппятся явно в заранее согласованную схему.
        default:
            break
        }
    }
}
```

Для production предпочтительнее exhaustively перечислить все cases без
`default`, чтобы компилятор заставил пересмотреть privacy/analytics schema при
добавлении нового события.

Не используйте reflection, `String(describing: event)`, универсальный encoder
в arbitrary dictionary или автоматическую отправку всех полей.

## Локальный recording fixture

`BroadAppTemplate` содержит bounded in-memory destination и debug-панель. Они
показывают реальную последовательность typed событий, но ничего не отправляют в
сеть.

1. Сгенерируйте и откройте example:

   ```bash
   ./Scripts/generate_example.sh
   open Examples/BroadAppTemplate/BroadAppTemplate.xcodeproj
   ```

2. Добавьте launch arguments:

   ```text
   -analytics-fixture
   -tracking-disabled
   ```

3. Выберите продукт, выполните fixture purchase и перейдите на main.
4. Нажмите кнопку с инструментами в верхней панели.
5. Нажмите `Refresh recorded events` или потяните список вниз, чтобы обновить
   `Recorded analytics`.

Для обычной fixture-покупки ожидается последовательность:

```text
paywall_load_started
paywall_load_success
paywall_shown
product_selected
purchase_started
entitlement_resolved
purchase_success
paywall_closed
```

Перед `paywall_load_started` может находиться стартовый
`entitlement_resolved(inactive)`: AppFlow сначала проверяет уже существующий
доступ и только затем выбирает initial paywall route.

Порядок последних двух событий может зависеть от решения host navigation, но
`purchase_success` появляется только после успешной entitlement-проверки.

Дополнительно прогоните:

- `-purchase-pending`: есть pending, нет ложного success/premium;
- `-purchase-cancelled`: cancellation не превращается в error/success;
- `-purchase-failure`: виден только safe diagnostic code;
- `-restore-nothing`: отдельный restore attempt и nothing-found outcome;
- `-paywall-many-products`: все 12 строк выбираются без изменения порядка.

Экран `Аналитика` в безопасном каталоге подписывается на recorder и обновляет
список сразу после нового typed-события. Кнопка `Обновить события` оставлена как
явная повторная сверка: на время чтения показывается progress, а рядом с числом
записей — время последнего обновления. Встроенная кнопка открывает fixture-paywall,
поэтому `load → shown → selection → close` можно проверить без покупки.

Кнопка `Очистить события` очищает только in-memory debug-историю, сообщает
количество удалённых записей и становится недоступной для пустого списка.
Полный перезапуск процесса также начинает историю с нуля. Recorder удерживает
максимум 256 событий и доступен только как fixture destination; это не
production storage.

Исходники примера:

- [analytics composition](../Examples/BroadAppTemplate/BroadAppTemplate/Infrastructure/Analytics/ExampleMonetizationAnalyticsAssembly.swift);
- [typed bounded recorder](../Examples/BroadAppTemplate/BroadAppTemplate/Infrastructure/Analytics/ExampleRecordingMonetizationAnalytics.swift);
- [debug presentation mapping](../Examples/BroadAppTemplate/BroadAppTemplate/Presentation/RootScene/ExampleAnalyticsViewModel.swift).

## Checklist перед интеграцией

- [ ] один shared analytics pipeline передан во все monetization components;
- [ ] deduplication стоит до fan-out;
- [ ] Adapty provider lifecycle не подменён app analytics destination;
- [ ] requested/resolved placement и variation не теряются при fallback;
- [ ] selection содержит occurrence ID и SKU;
- [ ] Apple и RU conversion сохраняют paywall variation;
- [ ] destination использует explicit typed mapping без raw/reflection;
- [ ] PII, secrets, payment URLs и raw errors отсутствуют;
- [ ] медленный/упавший destination не влияет на checkout и entitlement;
- [ ] fixture-сценарии проверены до подключения live provider;
- [ ] live dashboard/export сверены на exact host build отдельно.
