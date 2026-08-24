# Purchase Managers

В платформе есть два независимых сценария. Выберите только тот, который нужен
приложению.

## Вариант 1 — только подписки

Используйте `SubscriptionPurchaseManager`. Он умеет:

- купить подписку через App Store, СБП или карту;
- восстановить Apple-покупки;
- вернуть единый `CheckoutSelectedProductOutcome`;
- открыть premium только после authoritative entitlement refresh.

```swift
let subscriptions = SubscriptionPurchaseManager(
    checkout: checkoutSelectedProduct,
    restorePurchases: restorePurchases
)

let outcome = await subscriptions.purchase(
    selection,
    using: .apple,
    remoteConfiguration: paywall.remoteConfiguration
)
```

Никакие token-протоколы, token backend или token balance этому варианту не
нужны.

## Вариант 2 — подписки и токены

Оставьте `SubscriptionPurchaseManager` для premium и рядом создайте отдельный
`TokenPurchaseManager`. Менеджеры не зависят друг от друга; общий у них только
app-wide `MonetizationOperationGate`, чтобы два платежа не стартовали
одновременно.

```swift
let tokenStore = PendingTokenPurchaseStore(
    subject: subject,
    applicationIdentifier: bundleID,
    cache: cache
)

let tokens = TokenPurchaseManager(
    purchaseRepository: adaptyPurchaseRepository,
    evidenceProvider: StoreKitTokenTransactionEvidenceProvider(
        appBundleIdentifier: bundleID,
        ownershipPolicy: .appStoreAccount
    ),
    fulfillmentRepository: appTokenBackend,
    pendingStore: tokenStore,
    analytics: analytics,
    operationGate: sharedOperationGate
)
```

`appTokenBackend` реализует один узкий протокол:

```swift
struct AppTokenBackend: TokenFulfillmentRepositoryProtocol {
    func fulfill(
        _ request: TokenFulfillmentRequest
    ) async -> TokenFulfillmentOutcome {
        // Отправить request.evidence.signedTransaction на backend.
        // Backend атомарно зачисляет каждый transactionID только один
        // раз и возвращает актуальный баланс авторизованного app account.
    }
}
```

Главные правила:

1. На устройстве не увеличиваем баланс «на глаз».
2. Источник баланса — только backend.
3. Backend обязан атомарно начислять один `transactionID` ровно один раз;
   повтор возвращает `.alreadyCredited` и текущий balance snapshot.
4. До открытия Apple sheet сохраняется durable intent.
5. После подтверждения StoreKit сохраняется signed evidence.
6. Если приложение закрыли между покупкой и backend sync, вызовите
   `recoverPendingPurchase()` на launch и при возврате в active.
7. Pending fulfillment блокирует повторное списание, но не притворяется
   успешной покупкой.

## После удаления и новой установки

`PendingTokenPurchaseStore` переживает закрытие процесса, но удаляется вместе с
приложением. Поэтому он защищает покупку, а не является хранилищем баланса.

После login вызовите `RecoverCustomerAccessUseCase` с app-specific
`RecoverTokenAccountUseCaseProtocol`. Backend определяет user по server authorization и
возвращает полный `TokenBalanceSnapshot`. Именно этот snapshot показывает UI;
клиент не передаёт список transaction/checkout ID для обычного recovery.

```swift
let recovery = services.makeCustomerAccessRecovery(
    subject: authenticatedSubject,
    refreshEntitlement: entitlementEngine,
    recoverTokenAccount: appTokenAccountRecovery
)

let snapshot = await recovery()
if case let .restored(balance) = snapshot.tokens {
    tokenStore.applyAuthoritative(balance)
}
```

StoreKit `restorePurchases()` не возвращает consumables. Без стабильного app
account, server balance и защиты начислений от дублей восстановить токены после
переустановки невозможно.
[Полный contract →](AccountRecovery.md).

При внезапном обрыве сети после StoreKit confirmation менеджер не начисляет
баланс локально и не запускает второй charge: сохранённый JWS повторно отправляет
`recoverPendingPurchase()`. [Все network cases →](NetworkInterruptions.md).

StoreKit sandbox и реальные списания не входят в локальную приёмку компании.
Для проверки package используются сборка и fixture-сценарии; production backend
проверяет команда конкретного приложения.

## Какой вариант выбрать

| Приложение | Что подключить |
|---|---|
| Только premium-подписка | `SubscriptionPurchaseManager` |
| Подписка + пакеты токенов | оба менеджера |
| Только токены | только `TokenPurchaseManager` |
| Токены через RU backend | app-specific `TokenFulfillmentRepositoryProtocol`; не копируйте Apple JWS-схему в RU API автоматически |

[Общая монетизация →](Monetization.md) · [RU Billing →](RUBilling.md) ·
[Entitlements →](Entitlements.md) · [Account Recovery →](AccountRecovery.md) ·
[Token Paywall →](TokenPaywall.md)
