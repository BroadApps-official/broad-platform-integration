# Отдельный token paywall

`BroadTokenPaywallViewModel` и `BroadTokenPaywallView` обслуживают только
consumable-пакеты. Они визуально используют те же theme, product row и primary
button, что subscription paywall, но не импортируют его checkout, restore или
premium completion.

## Обязательная композиция

```text
placement .tokens
  → LoadPaywallUseCase
  → provider order без filter/sort/dedup
  → BroadTokenPaywallViewModel
  → TokenPurchaseManager
  → verified transaction evidence
  → TokenFulfillmentRepositoryProtocol
  → backend TokenBalanceSnapshot
  → onBalanceConfirmed(snapshot)
```

Общий `LoadPaywallUseCase` сохраняет резерв любого placement на `.main`.
Token ViewModel принимает такой fallback только когда requested context остался
`.tokens`, origin содержит typed fallback, а **все** продукты резервного
каталога имеют `kind == .consumable`. Subscription/unknown-продукт из `main`
отклоняет весь payload: обычный subscription paywall не может подменить token
flow. Строки принятого каталога не сортируются и не дедуплицируются. Купить можно
только consumable с валидной числовой ценой.

Баланс меняется только после `.credited` или `.alreadyCredited` от backend.
`pending`, cancellation, provider failure, offline и backend error не меняют
баланс и не выдают premium. Безопасный retry сначала вызывает
`recoverPendingPurchase()`; новый provider checkout начинается только когда
pending intent действительно отсутствует.

## Template fixture

На main есть отдельный backend-confirmed token balance. И баланс, и карточка
`Token paywall` открывают один и тот же настоящий fixture-flow. Каталог содержит
сценарии:

- немедленное `credited`;
- `pending` с повторной reconciliation после переоткрытия;
- `cancelled`;
- provider failure до списания;
- backend error и идемпотентный retry;
- offline и повторная отправка сохранённого evidence без второго charge.
- `-token-paywall-main-fallback`: `.tokens` недоступен, `main` возвращает только
  consumable-пакеты, UI остаётся token paywall и сохраняет requested `.tokens`.

Fixture backend начинает с безопасного server snapshot `120`, хранит ledger по
transaction ID и возвращает `.alreadyCredited` при повторной доставке того же
доказательства. Это демонстрация контракта: настоящий баланс между установками
обязан храниться backend конкретного приложения.

Отдельная bounded token-аналитика видна прямо на экране. Она содержит только
типизированные названия событий и не показывает transaction ID или signed
evidence.

## Account recovery

После login вызывайте `RecoverCustomerAccessUseCase` или app-specific
`RecoverTokenAccountUseCaseProtocol`. Callback получает только подтверждённый
`TokenBalanceSnapshot`. Consumable нельзя восстановить кнопкой StoreKit Restore,
а локальный installation cache не является источником правды.

[Purchase Managers →](PurchaseManagers.md) ·
[Account Recovery →](AccountRecovery.md) ·
[Network Interruptions →](NetworkInterruptions.md) ·
[Template acceptance →](TemplateAcceptance.md)
