# Адаптивный paywall UI

`BroadUIFlows` содержит готовый SwiftUI-paywall, который работает поверх Domain-контрактов `BroadMonetization`. Presentation не импортирует Adapty/StoreKit, не знает provider placement ID, не создаёт repository и не обращается к DI-контейнеру.

## Где лежит

```text
Sources/BroadUIFlows/Presentation/Paywall/
├── BroadPaywallConfiguration.swift       # placement, тексты, legal links, default selection
├── BroadPaywallTokens.swift              # app-supplied palette, typography и metrics
├── BroadPaywallProductFormatter.swift    # реальные price/period без догадок
├── BroadSpecialOfferMetadataView.swift # optional remote offer fields и countdown
├── BroadPaywallViewState.swift           # loading/content/empty/error и completion
├── PaywallViewModel*.swift               # orchestration только через use-case protocols
├── BroadPaywallView*.swift               # адаптивный экран и sticky controls
├── BroadSelectableProductRow.swift       # строка продукта без press-эффекта
├── BroadPaywallPrimaryButton.swift        # CTA без scale/opacity/dimming
├── BroadPaymentMethodSheet.swift          # выбор Apple/SBP/card
├── BroadPaywallLegalFooter.swift          # legal links
└── BroadInAppSafariView.swift             # SFSafariViewController wrapper
```

## Главный контракт продуктов

Renderer проходит `PaywallPayload.products` ровно в provider order:

```swift
ForEach(payload.products, id: \.presentationID) { product in
    // одна UI-строка на каждое фактическое вхождение
}
```

Он ничего не фильтрует, не сортирует и не дедуплицирует. Два элемента с одинаковым `productID` или `ProductReference` остаются двумя строками, потому что UI identity — уникальный `ProductPresentationID`. Поэтому paywall безопасен для 0, 1, 2 и любого большего количества продуктов.

Даже malformed `vendorProductId` не отменяет всю Adapty-выдачу и не
удаляет одну строку. Adapter даёт такому occurrence детерминированный
ограниченный opaque surrogate, построенный из SHA-256 commercial fingerprint
без raw provider ID, и принудительно оставляет `Money == nil`. Строка
видима на исходной позиции, но semantic disabled и fail-before-charge.

`defaultSelection` применяется до первого render:

- `.presentationID` выбирает точное вхождение;
- `.productID` выбирает первое совпадение в provider order;
- `.index` выбирает фактический индекс без перестановки;
- отсутствующее/невалидное предпочтение откатывается к первому продукту;
- пустой массив не создаёт фиктивный выбор.

`ProductSelection` создаётся только через `SelectProductUseCase` и сохраняет exact
`PaywallVariationID`, provider-array index, SKU, opaque `ProductReference` и
`commercialFingerprint` выбранного occurrence. UI не реконструирует selection по
SKU. Если cached Adapty handle нужно rehydrate, purchase adapter разрешит его
только при exact variation + index + SKU + fingerprint match. Изменившиеся
price/period/offer terms дают safe reload-required failure до provider sheet;
молча купить новое предложение вместо показанного нельзя.

## Цена и период

`BroadPaywallProductFormatter` сначала требует валидный `Money`, а затем
использует только данные этого продукта:

1. при наличии `Money` предпочитает готовый provider `displayPrice`;
2. иначе форматирует фактические `Money.amount + currencyCode` в переданной `Locale`;
3. без `Money` показывает app-supplied `unavailablePriceTitle`, даже если пришёл
   один неподтверждённый display string.

Текст `displayPrice` разрешено показать только рядом с валидным `Money`: сам по
себе он не доказывает корректность суммы для финансовой операции. Если `Money`
отсутствует, occurrence сохраняет исходное место в списке и показывает fallback
price, однако строка semantic disabled, не участвует в default selection, CTA
остаётся выключенным, а checkout/purchase use cases повторно отклоняют вызов до
Apple/RU adapter-а.
Если eligible-продуктов нет совсем, close становится доступен сразу даже при
hard policy: disabled каталог не может запереть пользователя.

Период строится только из `SubscriptionPeriod`. Поддерживаются `day`, `week`, `month`, `year`, любое `custom(unit:)` и `unknown`. Для `unknown` значение по умолчанию отсутствует: экран не выдумывает неделю/месяц/год. Если продукту нужен честный общий текст, приложение явно задаёт `BroadPaywallPeriodCopy.unknownTitle`.

Платформа не вычисляет псевдоскидки, зачёркнутые цены или «цену в день». Special offer может показать зачёркнутое значение только когда оно явно пришло в valid remote config. SKU и суммы в UI не хардкодятся.

## Optional special-offer metadata

Если `remoteConfiguration.specialOffer` отсутствует или выключен, дополнительный UI не создаётся. При включённом offer каждое поле независимо:

- `badge`, `crossedPrice/crossedValue`, `priceMultiplier` и `periodText` показываются только при наличии;
- пропущенное поле скрывает только свой элемент;
- countdown получает `SpecialOfferCountdownAuthorization` из verified resolution;
- runtime expiry использует monotonic deadline; `expiresAt` нельзя сравнивать с device `Date()`;
- без duration offer показывается без countdown;
- числа локализуются, но не вычисляются из цены продукта.

Remote metadata и timer разрешены только когда
`BroadPaywallConfiguration.specialOfferAuthorization.paywallPresentationID`
совпадает с текущим payload. Это не даёт cached/другой презентации унаследовать
чужой special-offer gate.

Когда monotonic deadline в `specialOfferAuthorization.countdown` наступил, ViewModel отменяет ещё не начатый
checkout-resolution, скрывает offer metadata, снимает выбор продукта, блокирует
CTA/строки без визуального dimming, показывает app-supplied expired message и
делает close доступным. Уже начатая финансовая операция не отменяется и всё равно
доходит до authoritative entitlement refresh. При отсутствии `countdown` задача
таймера вообще не создаётся.

`PaywallViewModel(initialPayload:)` позволяет передать payload, уже проверенный `ResolveSpecialOfferUseCase`, без повторного placement-запроса. Shown analytics и hard-close delay стартуют только при фактическом `onAppear`.

## ViewModel и зависимости

Composition root создаёт use cases и передаёт их одной группой:

```swift
let dependencies = PaywallViewModelDependencies(
    loadPaywall: loadPaywallUseCase,
    selectProduct: selectProductUseCase,
    checkoutProduct: checkoutSelectedProductUseCase,
    restorePurchases: restorePurchasesUseCase,
    resolveCheckoutMethods: resolveCheckoutMethodsUseCase,
    trackEvent: services.trackPaywallEvent,
    presentationLifecycle: services.paywallPresentationLifecycle,
    operationGate: services.operationGate
)

let configuration = BroadPaywallConfiguration(
    placementID: .onboarding,
    defaultSelection: .productID(appPreferredProductID),
    access: BroadPaywallAccessConfiguration(
        defaultPolicy: .soft
    ),
    copy: appPaywallCopy,
    legalLinks: appLegalLinks
)

let viewModel = PaywallViewModel(
    configuration: configuration,
    dependencies: dependencies
)
```

`PaywallViewModel` зависит только от:

- `LoadPaywallUseCaseProtocol`;
- `SelectProductUseCaseProtocol`;
- `CheckoutSelectedProductUseCaseProtocol`;
- `RestorePurchasesUseCaseProtocol`;
- `ResolveCheckoutMethodsUseCaseProtocol`;
- `TrackPaywallEventUseCaseProtocol`;
- `PaywallPresentationLifecycleProtocol`;
- один app-wide `MonetizationOperationGate`.

`trackEvent` и `presentationLifecycle` должны прийти из одной
`BroadMonetizationServices` composition. Provider handle release не является
best-effort analytics: lifecycle выполняется отдельно, а typed analytics уже после
него. `operationGate` должен быть тем же instance, который использует purchase,
restore и optional RU composition.

SwiftUI-view получает готовый ViewModel через init. Внутри View нет Swinject, SDK activation, network client или provider object.

Provider-neutral checkout boundary сохраняет семантику результата: App Store
может завершиться verified entitlement, а открытие внешней RU payment page даёт
только pending notice. Premium completion приходит позднее от host-owned
`RUPaymentReturnCoordinator` после возврата приложения и authoritative refresh.

## Подключение View

```swift
BroadPaywallView(
    viewModel: viewModel,
    theme: appPaywallTheme,
    productFormatter: BroadPaywallProductFormatter(
        locale: appLocale,
        periodCopy: localizedPeriodCopy
    ),
    onClose: appFlowCoordinator.paywallDismissed,
    onCompleted: handlePaywallCompletion
)
```

`onCompleted` различает `.purchased(EntitlementSnapshot)` и `.restored(EntitlementSnapshot)`. Callback приходит только после подтверждённого authoritative entitlement. `completedButUnverified` остаётся на paywall с отдельным app-supplied сообщением и не выдаётся за premium-доступ.

## Состояния и безопасный выход

| State | UI | Close |
|---|---|---|
| `idle/loading` | loader и app-supplied текст | сразу для soft policy |
| `content` | весь массив продуктов в scroll | по effective access policy |
| `empty` | отдельный empty + retry | всегда доступен, включая hard paywall |
| `failure` | безопасный `AppError.userMessage` + retry | всегда доступен |

Effective policy берётся из valid remote configuration, а при отсутствии поля — из app configuration. Для `.hard` с продуктами:

- remote `closeDelay` имеет приоритет;
- иначе используется `hardPaywallCloseDelay` приложения;
- `nil` использует безопасный finite default `5` секунд;
- `0` означает immediate close;
- положительный delay ограничивается public maximum `30` секунд и выдерживается cancellable-задачей;
- empty/error никогда не превращаются в ловушку без выхода.

При уходе View отменяются load/checkout-resolution/close/offer-timer задачи.
Purchase и restore намеренно продолжаются: скрытие экрана или системная
презентация не должны потерять завершившуюся финансовую операцию и последующий
entitlement refresh.

В UI не выводятся `diagnosticCode`, raw SDK error или `localizedDescription`.

## Purchase, restore и способы оплаты

CTA сначала вызывает `ResolveCheckoutMethodsUseCaseProtocol` для выбранного точного `ProductSelection` и remote configuration:

- один Apple method запускается сразу; даже один RU method открывает consent sheet;
- несколько показываются в `BroadPaymentMethodSheet` в порядке use case;
- пустой список даёт безопасную retryable UI-ошибку;
- `.cancelled` не показывает ложную ошибку;
- `.pending` показывает app-supplied notice;
- `.completedButUnverified` сообщает, что операция завершилась, но доступ ещё не подтверждён, и не закрывает paywall;
- `.failed` показывает только безопасный `AppError.userMessage`.

RU billing не определяется UI по языку, locale, IP или timezone. Sheet отображает только методы, разрешённые monetization use case после проверки App Store storefront и конфигурации. Для СБП/карты он собирает обязательные offer/data-processing и recurring-charge consent, а также опциональный receipt email; Apple эти поля скрывает. Русские legal links задаёт приложение через `BroadRUBillingPresentationConfiguration`.

Renderer по-прежнему показывает occurrences без валидного `Money`, а также
`.consumable`/`.unknown`, и не фильтрует их. Они остаются disabled/unselected.
Generic checkout предназначен для premium entitlements и fail-before-charge
возвращает safe unavailable: без проверенной суммы нельзя открывать финансовый
flow, а без durable exactly-once token fulfillment списание могло бы завершиться
без выдачи. Consumable CTA подключается только отдельной host fulfillment
composition с idempotent ledger/recovery; generic paywall не обещает token
delivery.

На `viewDidAppear` и после каждого financial outcome ViewModel спрашивает
`operationGate.isFinancialOperationBlocked()`. Persisted Apple Ask-to-Buy,
ambiguous Apple result или RU session отключают product rows/CTA/restore без
opacity/scale/dimming; close остаётся доступен по обычной access policy. Локальный
`isPurchaseInFlight` не подменяет durable blocker. До завершения асинхронного
чтения gate состояние считается blocked; refresh также закрывает устаревший
method sheet и отменяет ещё не завершённый checkout-method resolution.

Restore доступен отдельным sticky action. `.nothingFound`, `.unavailable` и `.failed` не считаются успешным восстановлением. `.restored` передаёт только уже подтверждённый entitlement snapshot.

## Никаких мерцаний при tap/purchase

Product row, CTA, restore, close, legal links и payment methods используют `BroadNoPressEffectButtonStyle`. Стиль возвращает label без изменения `scale`, `opacity`, brightness или overlay.

Во время purchase весь paywall блокирует касания через `allowsHitTesting`, но визуально не затемняется. Progress показывается как отдельный элемент CTA. Selection border/surface меняются только как явное состояние выбранного продукта; implicit animation отсутствует.

## Sticky layout и адаптивность

- при обычных Dynamic Type-размерах close находится над product scroll, а CTA, feedback, restore и legal footer остаются в sticky footer;
- при accessibility Dynamic Type весь paywall становится единым scroll flow: `close → header → все products → CTA → feedback → restore → legal`;
- accessibility-ветка не создаёт вложенный `ScrollView`, поэтому header/footer не могут сжать product viewport до нуля на iPhone SE;
- заголовок и любое количество product rows остаются достижимыми в обеих layout-стратегиях;
- ширина контента ограничивается token `maximumContentWidth`, поэтому строки не растягиваются даже на самом широком поддерживаемом iPhone;
- product row использует `ViewThatFits`: длинная цена уходит под описание вместо обрезки;
- все тексты допускают несколько строк и Dynamic Type;
- экран не задаёт фиксированную высоту title/subtitle/legal text;
- product, CTA, restore, payment-method, legal и close hit-area не меньше
  `44×44` немасштабируемых points даже на узком экране или в custom theme;
- semantic colors поддерживают light/dark mode;
- выбор продукта не использует motion, поэтому Reduce Motion не требует альтернативы.

Локальная приёмка использует доступные Simulator/fixture-сценарии и source
review semantic labels/traits. Device VoiceOver/Dynamic Type matrix не входит в
company acceptance и не блокирует передачу package. Light/dark с app-owned
colors, реальные payment-method sheet detents и RU Safari-return разработчики
проверяют позднее при интеграции конкретного приложения.

## Legal links

Приложение передаёт массив `BroadPaywallLegalLink` с уникальными ID и HTTPS URL. Footer не знает названий «Privacy»/«Terms» и использует app-supplied локализованный текст. По умолчанию ссылка открывается внутри приложения через `BroadInAppSafariView`; внешний Safari и собственный web-router можно использовать отдельно вне готового View.

## Ручная приёмка без test target

Проверить минимум:

- 0 продуктов: empty, retry, restore и close; hard policy не скрывает close;
- 1 продукт: выбран автоматически, один method стартует без sheet;
- 2 одинаковых SKU: две строки, независимые `presentationID`, provider order сохранён;
- malformed/blank/слишком длинный Adapty `vendorProductId`: все occurrences
  остались 1:1 и в provider order, а битая строка disabled и не открывает checkout;
- 20+ продуктов: product list scroll, sticky footer остаётся на месте;
- day/week/month/year/custom/unknown periods без выдуманных значений;
- только `displayPrice`, только `Money`, полностью отсутствующая цена; без
  `Money` строка видима, disabled и никогда не открывает checkout;
- hard paywall, в котором все occurrences неeligible: строки видимы, CTA disabled,
  close доступен немедленно;
- default selection по presentation/product/index и fallback к первому eligible;
- soft, hard с безопасным default, zero/delayed/capped close;
- Apple-only, RU-only и несколько checkout methods;
- cancelled, pending, failed и successful purchase;
- consumable отображается, но generic CTA возвращает safe failure без provider sheet;
- cached selection с изменёнными variation/index/SKU/terms не покупается;
- nothing found, unavailable, failed и successful restore;
- быстрые повторные taps не создают параллельный purchase/restore;
- все product rows semantic disabled во время checkout resolution,
  purchase, restore и durable Apple/RU pending, но остаются видимыми без dimming;
- во время purchase нет opacity/scale/dimming и заблокированы касания;
- long localization и light/dark fixtures в доступном Simulator matrix;
- наличие semantic labels/traits и scalable layout по source contract, без
  обязательного device VoiceOver/Dynamic Type прогона.
