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

## Remote Config не создаёт второй эксперимент

`special_offer` и `ru_pay` парсятся из того же paywall payload, который уже
содержит назначенную Adapty variation. Special Offer может использовать
`.providerCacheFallbackPossible`, а RU Billing дополнительно требует `.verifiedFreshRemote`.
Эти флаги управляют отображением функций, но не
назначают cohort. Стандартный Adapty payload сохраняет
`.providerCacheFallbackPossible`; raw paywall/products остаются во внутреннем
registry и purchase получает attribution той же presentation.

Platform-cache payload может отрисовать тарифы, но не включает эти gates. Для
Special Offer не нужен custom REST и повторный load: это могло бы создать другой
paywall/variation и разорвать attribution.

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

## Матрица приёмки

Матрица разделена на два уровня. Платформенный контракт проверяется локально и
не обращается к Adapty dashboard. Фактическое распределение пользователей между
вариантами подтверждается отдельно в Adapty: только провайдер знает experiment
configuration и назначенный конкретному профилю вариант.

### Автоматическая проверка платформы

Запустите из корня репозитория:

```bash
bash Scripts/check_adapty_experiment_contracts.sh
```

Эта команда входит и в полный `agent_gate`. Она не запускает покупку, restore,
RU-платёж или live Adapty SDK operation.

| Что проверяется | Ожидаемый контракт | Статус |
|---|---|:---:|
| Повторный show одной presentation | До SDK резервируется не более одной попытки provider show | ✅ |
| Новая presentation | Создаются новые paywall- и product-occurrence ID | ✅ |
| Variation attribution | Одна opaque variation проходит из Adapty payload в show, selection и purchase analytics | ✅ |
| Fallback на `main` | Requested placement сохраняется, resolved становится `main`, variation берётся из payload `main` | ✅ |
| Cached-only paywall | Загрузка из cache сама не создаёт provider impression | ✅ |
| Raw-handle eviction | Rehydration требует точного variation/index/SKU/commercial fingerprint | ✅ |
| `uiVariantID` | Остаётся renderer metadata и не участвует в Adapty assignment | ✅ |
| Assignment authority | В коде нет второго experiment/cohort randomizer | ✅ |
| Identity composition | Load, show, purchase и restore получают один factory-owned identity provider | ✅ |
| Remote feature gates | Provider payload разрешает Special Offer; RU требует verified freshness; raw product остаётся в registry | ✅ |

`✅` здесь означает: контракт закреплён исходниками и обязательным regression
guard. Это не утверждение о настройках конкретного проекта в Adapty dashboard.

### Проверка конкретного приложения в Adapty

Эти два пункта выполняются после создания experiments и placements конкретного
приложения:

- [ ] на одном тестовом Adapty profile открыть обычный experiment и сверить
  placement/variation в dashboard с app analytics;
- [ ] на том же profile пройти cross-placement flow и убедиться, что каждую
  variation назначил Adapty, а requested/resolved placement и fallback reason
  записаны без подмены.

Для этой проверки не нужна настоящая покупка. Если проверяется purchase
attribution, используется только разрешённый командой безопасный сценарий;
платформа сама не запускает StoreKit sandbox или финансовую операцию.

## Границы безопасности

- Analytics context не содержит email, payment URL, bearer,
  provider transaction ID или raw user identity.
- В событие попадают только safe typed identifiers, `AppError.Kind` и
  безопасный `diagnosticCode`.
- Ошибка analytics не меняет purchase result, attribution и entitlement.
