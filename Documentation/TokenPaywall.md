# Отдельный token paywall

## Когда открывать

Любое действие, которому не хватает токенов (генерация, повтор, шаблон, «ещё
раз»), сразу открывает пейвол. Нажатие на баланс токенов в шапке ведёт туда же.
Алерт «Not enough tokens… top up later» вместо пейвола запрещён.

```text
Нет подписки → подписочный пейвол кнопки/экрана (обычно pro_icon)
Есть подписка, не хватает токенов → token paywall (placement tokens, BroadTokenPaywallHost)
Тап по балансу → тот же выбор по наличию подписки
```

После покупки токенов перечитайте баланс с сервера и примените подтверждённый
`TokenBalanceSnapshot`. Действие пользователь запускает сам; автоматически
повторять генерацию нельзя. Если backend продаёт токены только подписчикам
(`403 subscription_required`), после покупки подписки, Restore и при запуске
отправляйте подписку на backend через `subscription/sync` или аналогичный метод.
Без этого не заработают кредиты за подписку и покупка токенов.

`BroadTokenPaywallViewModel` и `BroadTokenPaywallView` обслуживают только
consumable-пакеты. Они визуально используют те же theme, product row и primary
button, что subscription paywall, но не импортируют его checkout, restore или
premium completion.

На экране название пакета берётся из отображаемого имени StoreKit (в Debug —
`displayName` локализации `.storekit`), а количество токенов — из каталога
backend (credits по product ID) или из полного названия продукта; число из
product ID не извлекается, в том числе регулярным выражением.

Экран по Figma рисуется внутри `BroadTokenPaywallHost` (BroadUIFlows 6.2.0): хост
ведёт загрузку, выбор, покупку и зачисление, баланс и безопасную проверку
сохранённой покупки. Экран получает `BroadTokenPaywallScreen`: `packages`,
`balanceText`, `needsConfirmation`, `noticeMessage` и действия `purchase()`,
`confirm()`, `refreshBalance()`. `confirm()` никогда не списывает повторно.

Для RU-токенов с 3.0.0 есть отдельные `resolveTokenCheckoutMethods` и
`startSelectedToken` с подтверждением через account policy. Они подключаются
в собственном host UI; готовый экран ниже обслуживает Apple manager.
[Подключение RU checkout и возврата](RUBilling.md).

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

Стандартный Adapty adapter пробует token/tokens и не подменяет продукты `main`.
В host app для Debug подключите `TokenPurchaseManager` к
`LocalStoreKitPurchaseRepository` и добавьте consumable-продукты placement `tokens`
в локальный `.storekit` с ценами App Store; в Release покупка идёт через Adapty.
То же Debug-подключение нужно подписочным путям через
`PurchaseSelectedProductUseCase`.
Ниже описана защитная обработка legacy/custom payload в UI и fixture.
Token ViewModel принимает такой payload только когда requested context остался
`.tokens`, origin содержит typed fallback, а **все** продукты резервного
каталога имеют `kind == .consumable`. Subscription/unknown-продукт из `main`
отклоняет весь payload: обычный subscription paywall не может подменить token
flow. Строки принятого каталога не сортируются и не дедуплицируются. Купить можно
только consumable с валидной числовой ценой.

Product ID пакета в каталоге backend совпадает с продуктом Adapty/App Store символ
в символ, с регистром. Иначе backend отвечает `422` (`.rejected`): покупка прошла,
токены не начислены. Приложение ID не нормализует и не подбирает по цене —
каталог сводят аккаунт-менеджер и backend.

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

Fixture backend начинает с безопасного server snapshot `120`, атомарно
обрабатывает каждый transaction ID один раз и возвращает `.alreadyCredited` при
повторной доставке того же доказательства. Это демонстрация двух отдельных
контрактов: fulfillment защищён от дублей, а обычный recovery загружает полный
баланс авторизованного app account без списка transaction ID.

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
