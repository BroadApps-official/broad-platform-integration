# Восстановление после переустановки

Удаление приложения стирает `UserDefaults`, platform cache и pending-записи.
Поэтому ни premium, ни токены, ни RU-подписка не должны принадлежать конкретной
установке iPhone.

## Что является источником правды

| Покупка | Откуда восстанавливается | Что требуется от приложения |
|---|---|---|
| Apple subscription/lifetime | StoreKit current entitlements, Adapty и настроенный primary backend | тот же App Store account; app account улучшает identity/attribution |
| Apple token pack | актуальный balance snapshot текущего app account с backend | войти в тот же app account и вызвать account-scoped balance endpoint |
| RU subscription/lifetime | RU backend entitlement | вход в тот же app account; покупка привязана к server customer ID |
| RU token pack | тот же backend balance snapshot текущего app account | войти в тот же app account; клиенту не нужен список checkout ID |
| История Usedesk | user chat token в backend-профиле | вход в тот же app account; Keychain может быть только account-scoped cache |

> [!IMPORTANT]
> Consumable-токены нельзя восстановить кнопкой StoreKit Restore. После
> переустановки возвращается **серверный баланс пользователя**, а не локальная
> сумма покупок. Без стабильного app account гарантировать восстановление
> токенов и RU-покупок невозможно.

## Чтение баланса и начисление — разные операции

Обычное восстановление должно быть простым account read:

```text
login в тот же app account
  → GET /me/token-balance
  → backend определяет user по server authorization
  → возвращает полный TokenBalanceSnapshot
```

Клиент не передаёт список StoreKit transaction ID или RU checkout ID
для такого чтения. Эти ID нужны в другой точке — когда backend
зачисляет новую покупку.

Пример: backend зачислил 50 токенов, но ответ потерялся. Приложение
повторит то же доказательство. Если backend не запомнил уникальный
ID операции, он ошибочно зачислит ещё 50. Поэтому зачисление должно
быть атомарным:

```text
проверить signed Apple transaction / статус RU checkout
  → вставить unique (provider, environment, externalOperationID)
  → если ID новый: увеличить balance того же user
  → если ID уже был: не начислять повторно
  → вернуть текущий balance snapshot
```

Это не требует сложного event-sourcing. Достаточно таблицы баланса по
`userID` и таблицы уже обработанных покупок с unique constraint. Один
пользователь может легально купить один token pack несколько раз, поэтому
дедуплицировать только по `userID` или product ID нельзя.

[Apple: consumable не восстанавливается через Restore](https://developer.apple.com/documentation/storekit/skpaymentqueue/restorecompletedtransactions%28%29) ·
[Apple: transaction ID уникален для транзакции](https://developer.apple.com/documentation/appstoreserverapi/transactionid)

## Порядок на чистой установке

```text
launch
  → восстановить login/session пользователя
  → создать тот же fingerprinted EntitlementSubject
  → подготовить Adapty identity и subject-bound backend adapters
  → RecoverCustomerAccessUseCase
       ├─ fresh entitlement refresh: Apple + primary backend + RU
       ├─ token backend reconciliation → authoritative balance
       └─ RU backend status → plan / paid-through / renewal state
  → открыть premium только при entitlement.active
  → показать token balance только из backend snapshot
```

Запускайте recovery после login и до принятия решения о premium route. Повторяйте
его после account switch. На обычном foreground сначала завершите pending Apple,
token и RU flows, затем сделайте fresh recovery.

Если сеть пропала во время recovery, entitlement остаётся `unresolved`, а token
или RU component — `.unavailable`; нулевое значение не выдумывается. После
возвращения связи безопасно повторить весь recovery, потому что его backend
операции обязаны быть read/reconciliation и идемпотентными.

## Сборка

```swift
let recovery = monetizationServices.makeCustomerAccessRecovery(
    subject: entitlementSubject,
    refreshEntitlement: entitlementEngine,
    recoverTokenAccount: appTokenAccountRecovery,
    loadRUSubscription: ruServices.checkout.loadSubscriptionStatus
)

let snapshot = await recovery()

if snapshot.entitlement.state == .active {
    openPremiumContent()
}

if case let .restored(balance) = snapshot.tokens {
    tokenStore.applyAuthoritative(balance)
}
```

`appTokenAccountRecovery` реализует
`RecoverTokenAccountUseCaseProtocol`. Его обычный backend-вызов:

1. определяет текущего пользователя по server authorization;
2. не доверяет произвольному `userID` из query/body;
3. возвращает полный актуальный `TokenBalanceSnapshot` даже при нулевом
   балансе.

Если backend дополнительно выполняет reconciliation, он сам находит ещё не
зачисленные Apple/RU операции, атомарно обрабатывает их unique ID и
всё равно возвращает один полный balance snapshot. Приложению не нужно
передавать список ID для recovery.

Для окна между списанием и удалением приложения backend должен получать Apple
операции через App Store Server Notifications / Server API или выполнять
server-side reconciliation по связанному `appAccountToken`. Локальный
`PendingTokenPurchaseStore` защищает обычный cold launch, но после удаления
приложения сам по себе существовать не может.

## Apple subscription

`RecoverCustomerAccessUseCase` запускает новый authoritative entitlement refresh.
StoreKit current entitlements и server-backed источники проверяются заново, поэтому
отсутствие локального cache не означает отсутствие подписки.

Кнопка «Восстановить» остаётся обязательным ручным fallback. Она вызывает
`RestorePurchasesUseCase`, а затем тот же общий entitlement refresh. Никогда не
открывайте premium только по результату SDK restore.

## RU billing

RU checkout, subscription и paid-through дата принадлежат server customer, а не
установке. После login:

- зарегистрируйте RU entitlement source для того же `EntitlementSubject`;
- создайте новый current `SubjectAuthorizationBinding`;
- вызовите общий recovery;
- считайте активность из unified entitlement snapshot;
- считайте plan/cancel/renewal UI из `loadSubscriptionStatus`.

Email для чека — только удобство формы. Его потеря после удаления приложения не
должна влиять на оплату, entitlement или восстановление.

## Недопустимые реализации

- `isPremium = true` в `UserDefaults`;
- локальный token balance как источник правды;
- восстановление RU-доступа по locale, device ID или email из формы чека;
- повторное начисление по тому же StoreKit transaction ID или RU checkout ID;
- создание новой anonymous identity на каждой установке для server purchases;
- открытие premium при `.unresolved`, timeout или только cached inactive.
- хранение единственной копии Usedesk user chat token в `UserDefaults`/Keychain,
  привязка истории к device ID или передача token предыдущего
  пользователя после смены аккаунта.

[Entitlements →](Entitlements.md) · [Purchase Managers →](PurchaseManagers.md) ·
[RU Billing →](RUBilling.md) · [Network Interruptions →](NetworkInterruptions.md) ·
[Usedesk →](Usedesk.md) · [Security →](Security.md)
