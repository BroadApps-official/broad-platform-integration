# Adapty experiments

## Единственный источник assignment

Adapty SDK — единственный источник варианта для обычных и
cross-placement экспериментов. Конфигурация эксперимента, сегментация и
связь между placements живут в Adapty. Платформа:

- не рандомизирует пользователя;
- не хранит собственный experiment/segment assignment;
- не читает cohort из remote config;
- не пытается синхронизировать варианты между placements;
- не отправляет синтетические события назначения и показа варианта.

Хост должен активировать Adapty один раз и использовать один и тот же
identity provider для load, show, purchase и restore. Иначе нельзя ожидать
целостной cross-placement атрибуции.

## Как вариант проходит через платформу

`Adapty.getPaywall` возвращает уже выбранную Adapty variation. Платформа
сохраняет opaque ID без интерпретации:

```text
AdaptyPaywall.variationId
→ PaywallPayload.variationID
→ PaywallAnalyticsContext.variationID
→ ProductSelection.paywallVariationID
→ PurchaseAnalyticsContext.paywallVariationID
```

Первая ветка нужна для paywall load/show analytics. Вторая привязывает
выбранный продукт и purchase lifecycle к тому же paywall variant. `nil`
означает, что Adapty не вернул валидный variation ID; платформа не
придумывает замену.

`uiVariantID` из remote config — только metadata для выбора renderer. Он не
является experiment ID, segment или cohort и не влияет на Adapty assignment.

## Обычный и cross-placement сценарии

Для обычного эксперимента host запрашивает нужный logical placement,
а Adapty возвращает его текущую variation. Для cross-placement эксперимента
host так же запрашивает каждый placement независимо. Связь между
вариантами определяет Adapty, а не общий Swift-координатор.

Такой контракт исключает второй randomizer на клиенте и расхождение
между paywall, Adapty dashboard и purchase attribution.

## Fallback на main

При fallback платформа не переносит variation с неудачного primary
placement. Она загружает fallback placement как отдельный Adapty paywall:

```text
requestedPlacementID = исходный logical placement
resolvedPlacementID  = main
variationID          = variation, вернутая Adapty для main
fallbackReason       = причина перехода
```

В UI и app analytics всегда передаются оба placement ID. Это показывает,
где paywall запросили и откуда фактически пришли catalog и variation.
Платформа не переназначает cohort и не подменяет variation ID.

## Provider show lifecycle

App-level `paywallShown` и provider-level `Adapty.logShowPaywall` — разные
операции:

- `TrackPaywallShownUseCase` отправляет typed app analytics;
- тот же use case передаёт context в
  `AdaptyPaywallPresentationLifecycle`;
- lifecycle атомарно резервирует raw `AdaptyPaywall` до `await`;
- для одного `PaywallPresentationID` допускается не более одной
  локальной попытки `Adapty.logShowPaywall`;
- после `presentationDidEnd` raw handles освобождаются.

Резервирование подавляет concurrent дубли. «Не более одной попытки»
не означает guaranteed delivery: SDK/network может не принять вызов, а
released или cached-only presentation может не иметь raw handle.

## Cache и raw Adapty handles

Platform cache хранит provider-neutral `PaywallPayload`, но не сериализует
`AdaptyPaywall` и `AdaptyPaywallProduct`. Поэтому cached payload можно безопасно
отрисовать, но нельзя по одному Codable payload восстановить
provider show или purchase handle.

Если raw product ещё жив в registry, purchase использует именно его. Если
handle уже вытеснен, repository заново загружает
`resolvedPlacementID` и покупает только при точном совпадении:

- `paywallVariationID`;
- позиции в provider array;
- product ID;
- commercial fingerprint продукта.

Любое расхождение даёт безопасную unavailable-ошибку. Платформа не
покупает продукт из другой variation и не склеивает одинаковые SKU из
разных позиций.

## App analytics

Платформа даёт host-приложению typed lifecycle events:

- paywall load и show несут `requestedPlacementID`, `resolvedPlacementID`,
  `variationID`, fallback reason и presentation ID;
- product selection и purchase связаны с конкретным occurrence продукта;
- purchase events несут `paywallVariationID` и оба placement ID;
- `DeduplicatingMonetizationAnalytics` подавляет повторный app
  `paywallShown` для presentation и дубли purchase lifecycle для attempt.

Эти события нужны для аналитики приложения, но не создают вторую
систему experiment assignment поверх Adapty.

## Контракт composition root

Host подключает:

1. одну `AdaptyPlatformConfiguration`;
2. один `AdaptyIdentityProviderProtocol` для всей monetization composition;
3. app-owned mapping logical placements → Adapty placement IDs;
4. `AdaptyPaywallPresentationLifecycle` из той же factory/services
   composition, что и repositories;
5. app analytics destination без custom experiment randomizer.

Конкретные placement IDs не хардкодятся в экранах платформы. Обычные
и cross-placement эксперименты настраиваются в Adapty dashboard.

## Ручная приёмка

- [ ] повторный show callback одной presentation даёт не более одной
  попытки `Adapty.logShowPaywall`;
- [ ] новый `PaywallPresentationID` может отправить новый показ;
- [ ] variation ID в paywall show и purchase analytics совпадает с
  `AdaptyPaywall.variationId`;
- [ ] fallback на main сохраняет requested placement, но берёт variation из
  фактического main payload;
- [ ] обычный и cross-placement сценарии проверены на одном Adapty
  profile/identity;
- [ ] cached-only paywall не создаёт фальшивый provider show;
- [ ] покупка после raw-handle eviction проходит только при точном
  variation/index/product/fingerprint match;
- [ ] unknown `uiVariantID` переходит на app default и не меняет cohort;
- [ ] в codebase нет custom assignment repository/coordinator и client-side randomizer.

## Границы безопасности

- Analytics context не содержит email, payment URL, bearer,
  provider transaction ID или raw user identity.
- В событие попадают только safe typed identifiers, `AppError.Kind` и
  безопасный `diagnosticCode`.
- Ошибка analytics не меняет purchase result, attribution и entitlement.
