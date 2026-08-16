# Перенос существующего приложения

Переносите приложение вертикальными срезами, а не одним большим rewrite. Первый безопасный результат — один реальный маршрут `launch → onboarding → paywall → purchase/restore → main`, собранный на platform contracts. После этого можно переносить остальные placements и optional features.

## Главный принцип

```text
сначала app-owned configuration и adapters
→ затем Domain/Application contracts
→ затем ViewModel/UI
→ затем удаление legacy implementation
```

На каждом этапе должен существовать явный rollback: старый screen/adapter можно временно вернуть host feature flag, не меняя Domain и AppFlow.

## 0. Сделайте инвентаризацию

Зафиксируйте текущее состояние в одной таблице:

| Область | Что собрать |
|---|---|
| Startup | порядок SDK, blocking calls, timeout/retry, loader side effects |
| Onboarding | слайды, assets, ATT/review момент, progress storage |
| Paywalls | все места показа, provider placement IDs, hard/soft rules |
| Products | SKU, исторические premium SKU, periods, duplicates, sorting/filtering |
| Purchase/restore | SDK entry points, double-tap guards, результат и access grant |
| Entitlement | Apple/backend/RU authorities, TTL, offline behavior, user identity |
| Reinstall recovery | login restore, subscription ownership, token ledger, RU customer binding |
| Network interruption | обрыв до/во время/после каждого read и financial operation |
| Remote config | keys, aliases, defaults, last-valid behavior |
| RU billing | `ru_pay`, регион/язык iPhone, catalog mapping, consent/receipt UI, endpoints, return/polling/cancel/settings |
| Special offer | наличие feature, gate, window/cooldown, crossed-price fields |
| Experiments | Adapty placements, обычные/cross-placement вариации и attribution |
| Analytics | события, deduplication, PII/raw payload |
| Persistence | cache keys, schema versions, user-scoped state |

Отдельно пометьте все места, где legacy код:

- вызывает ATT из loader;
- показывает Rate Us/review внутри onboarding;
- выдаёт premium сразу после SDK purchase;
- определяет RU только по языку/региону без обязательного `ru_pay = true`;
- фильтрует или сортирует provider products;
- меняет opacity/scale при product tap;
- хранит keys/PII/raw errors.

Эти места нельзя переносить как есть.

## 1. Подключите package без изменения UI

Добавьте package из GitHub или локальной checkout-папки, три основных продукта
и при необходимости независимый `BroadExtensions`. Создайте
один `AppCompositionRoot`, но сначала оставьте legacy screen builders.

Проверка этапа:

- package собирается вместе с app target;
- assembly идут `BroadCore → BroadMonetization → BroadUIFlows`;
- Views не обращаются к Swinject;
- legacy SDK imports не попали в новые Domain/Presentation слои;
- `./Scripts/lint.sh` и `./Scripts/build.sh` проходят в platform workspace.

[Базовое подключение →](GettingStarted.md)

## 2. Вынесите app-owned configuration

Создайте app-level структуры для:

- локализованных текстов;
- assets/media IDs;
- legal HTTPS URLs;
- реальных Adapty placement IDs;
- runtime credentials/backend configuration;
- premium access level и append-only SKU catalog;
- bootstrap/timeout/cache policies;
- feature gates RU/special offer; эксперименты и cross-placement связи в Adapty Dashboard.

Не переносите реальные значения в shared package. Не читайте configuration напрямую из SwiftUI View.

Рекомендуемый ownership:

```text
Host Infrastructure/Configuration
├── AppIdentity
├── MonetizationConfiguration
├── AppTexts
├── AppLegalLinks
└── FeaturePolicies
```

## 3. Перенесите Core

### Bootstrap

Разделите старый startup на конечные `BootstrapStep`:

- critical только для действительно обязательного route decision;
- background для analytics/необязательных SDK;
- явный timeout для каждого шага;
- bounded retry;
- safe user message вместо raw error.

Удалите ATT/review и UI navigation из bootstrap. Loader отображает состояние, но не владеет startup side effects.

### Cache/offline

Для каждого legacy cache key определите:

- typed payload;
- стабильный schema identifier;
- version;
- TTL;
- допустим ли stale fallback;
- нужен ли user/source scope.

Сначала читайте старый формат через одноразовый app adapter, затем записывайте новый envelope. Не заставляйте shared repository угадывать legacy schema.

Отдельно удалите предположение, что локальный cache переживёт переустановку.
Premium ownership, token balance и RU purchases должны восстанавливаться из
StoreKit или backend текущего app account. Cache нужен только для ограниченного
offline UX.

### Logging

Замените console/raw logger на `BroadLoggerProtocol`. В новый event stream не переносите payload, identifiers, URL и `localizedDescription`.

[Bootstrap](Bootstrap.md) · [Cache migration](CachingAndOffline.md) · [Logging](Logging.md)

## 4. Перенесите AppFlow и onboarding

Создайте новый `AppFlowCoordinator` поверх отдельного progress store. Не копируйте premium flag в checkpoint.

Миграция progress:

| Legacy факт | Новый checkpoint |
|---|---|
| onboarding никогда не завершён | `.start` |
| onboarding завершён | `.onboardingCompleted` |
| initial paywall уже законно resolved | `.initialPaywallResolved` |

Checkpoint монотонный: не откатывайте завершённый onboarding из-за network error.

Onboarding переносится как конфигурация страниц. Media остаётся app-owned builder.

Обязательные исправления:

- ATT только `.afterFirstSlide`, после visible window/active scene;
- ATT policy `.disabled`, если prompt не нужен;
- Rate Us/review полностью удалить из onboarding;
- Rate Us за пределами onboarding можно оставить отдельным app flow;
- restore/footer legal actions передать host callback.

[AppFlow](AppFlow.md) · [Onboarding & ATT](OnboardingAndATT.md)

## 5. Введите typed placements

Составьте mapping всех legacy provider IDs:

| Legacy screen | Logical placement | Provider ID хранится |
|---|---|---|
| onboarding paywall | `.onboarding` | только в host registry |
| main premium | `.main` | только в host registry |
| settings premium | `.settings` | только в host registry |
| locked feature | `.feature` или `.custom(...)` | только в host registry |
| tokens | `.tokens` | только в host registry |
| discount | `.discount` | только в host registry |
| optional offer | `.specialOffer` | только если feature существует |

`.main` обязателен как общий fallback. Не используйте один provider ID для всех logical placements только ради простоты аналитики: requested/resolved origin должен оставаться различимым.

Проверьте цепочку:

```text
requested remote → requested cache → main remote → main cache → safe result
```

[Placements и fallback →](Monetization.md#3-загрузка-paywall-и-fallback-main)

## 6. Перенесите products без legacy-фильтров

Удалите из data/UI pipeline:

- allowlist текущих SKU;
- выбор только weekly/monthly/yearly;
- сортировку по цене/period;
- дедупликацию одинаковых vendor product IDs;
- ограничение `prefix(3)`/fixed index;
- fallback price/period strings.

Новый pipeline сохраняет каждый элемент 1:1 и в provider order. Premium entitlement catalog остаётся отдельным append-only списком — он **не является paywall filter**.

Перед включением нового UI прогоните:

- 0 products;
- 1 product;
- одинаковый SKU дважды;
- 12–20 products;
- unknown period;
- отсутствующий display price;
- длинные titles/localization.

[Product contract →](Monetization.md#4-products-строгий-контракт-11) · [Adaptive UI →](PaywallUI.md)

## 7. Перенесите purchase и restore

Сначала оставьте старый SDK adapter за новыми `PurchaseRepositoryProtocol`/`RestoreRepositoryProtocol`. Затем подключите platform Adapty adapters.

Измените точку выдачи доступа:

```text
раньше: SDK success → premium
теперь: SDK success → fresh entitlement generation → active → premium
```

Маппинг исходов:

| Legacy результат | Новый outcome |
|---|---|
| user cancelled | `.cancelled` |
| transaction pending | `.pending` |
| SDK success, entitlement не подтверждён | `.completedButUnverified` |
| SDK success + active snapshot | `.activated` |
| restore + active | `.restored` |
| restore + all inactive | `.nothingFound` |
| restore + unresolved | `.unavailable` |

Удалите любые прямые записи `isPremium = true` из purchase completion. AppFlow callback вызывается только для `.activated/.restored`.

Cached Adapty selection нельзя rehydrate только по SKU: нужны exact variation ID,
provider index и opaque commercial fingerprint цены/периода/offer terms. Mismatch
должен завершиться reload-required до charge. Generic paywall отображает
consumables, но standard premium purchase use case их не покупает; перенесите
token packs только в отдельную durable exactly-once fulfillment composition.

До включения нового purchase pipeline добавьте safety wiring:

- один process-wide `MonetizationOperationGate` для всех identity compositions,
  Apple purchase/restore и RU;
- production `VersionedJSONCacheRepository` + `PendingApplePurchaseStore` с
  app-wide `applicationIdentifier`, не in-memory fixture;
- один verified same-bundle `.purchase` `Transaction.updates` bridge до Adapty
  activation, без `transaction.finish()`;
- `PendingApplePurchaseCoordinator.applicationDidBecomeActive()` на launch и
  каждом реальном foreground transition;
- Ask-to-Buy/ambiguous provider error остаются durable `.pending`; user
  acknowledgement/review timeout никогда не clear-ит record. Нужен definitive
  pre-purchase cancel/failure или verified terminal reconciliation.

Pending records хранят originating subject и меняются через atomic
insert/compare-and-set/remove. Login/logout не должен перезаписывать или удалять
операцию другой identity.

## 8. Перенесите Entitlement Engine

Подключайте authority по одному:

1. Apple StoreKit с точным bundle ID и append-only premium catalog;
2. основной backend с subject-bound authorization;
3. RU billing source только после production-ready configuration.

Для каждого source задайте TTL и offline active grace. Проверьте матрицу active/inactive/unresolved до удаления legacy premium resolver.

После восстановления login подключите `RecoverCustomerAccessUseCase`: fresh
entitlement refresh, server token reconciliation и RU subscription status должны
выполняться для того же `EntitlementSubject`. Без стабильного app account нельзя
обещать восстановление consumable tokens и RU-покупок после переустановки.

Во время перехода два verifier одной Apple authority объединяются внутри `AppleEntitlementRepository`, а не регистрируются как независимые logical sources.

[Entitlement setup →](Entitlements.md) · [ADR →](ADR/0003-entitlement-authority.md)

## 9. Перенесите remote config

Сначала перечислите legacy aliases и создайте app-specific `RemoteConfigKeyRegistry`, не меняя backend. После стабилизации backend можно перейти на стандартные keys.

Зафиксируйте различия:

- absent обычное поле может сохранить last valid value своего placement;
- invalid поле не превращается в `false/0` автоматически;
- RU parser проверяет все aliases: любой false → `.disabled`, malformed/conflict
  без false → `.invalid`, ни одного alias → `.absent`;
- host RU fallback применяется только к `.absent`; cached/unqualified `.enabled`
  не авторизует billing;
- special offer не наследует previous gate;
- unknown UI variant использует app default;
- remote hard policy не может сделать empty/error экран без выхода.

[Remote Config →](RemoteConfig.md)

## 10. Решите optional features явно

### Special offer

Если приложение не показывает кампанию:

```swift
let specialOfferConfiguration: SpecialOfferConfiguration? = nil
```

Не создавайте пустой config «на будущее»: `nil` гарантирует ноль запросов/cache/timer/UI.

Если feature есть, мигрируйте placement, gate, window/cooldown и optional display fields. Старые hardcoded crossed prices удалите.

Resolver может вернуть `.eligible + paywall`, когда duration отсутствует:
показывайте offer без countdown. Передавайте только выданный
`SpecialOfferResolution.presentationAuthorization` в
`BroadPaywallConfiguration.specialOfferAuthorization`, а уже загруженный payload —
в `PaywallViewModel(initialPayload:)`. Это не создаёт второй placement request и
не даёт metadata/timer перейти на другой presentation. Любая persistence failure
скрывает offer fail-closed.

Если есть window/cooldown, добавьте `SpecialOfferClock` поверх доверенного server
time source. Не переносите старые сравнения с `Date()`: при отсутствии trusted
reading resolver возвращает `.unavailable(.untrustedTime)`. Создавайте
`.trusted(serverDate)` сразу после получения server time: reading сохраняет парный
monotonic instant, и открытый countdown не продлевается async-задержками.

### RU billing

Если feature не готова, используйте disabled composition и не добавляйте entitlement registration.

Если готова:

- eligibility требует свежий `ru_pay = true` и RU-регион iPhone или русский первый системный язык;
- absent/false/invalid/cached `ru_pay` fail-closed;
- catalog match typed/deterministic;
- HTTPS endpoints и subject-bound auth;
- pending context без URL/email/token;
- `RUBillingCompositionDependencies.applicationIdentifier` совпадает со
  стабильным app identifier Apple pending store;
- Safari return → polling → unified entitlement refresh;
- fresh install → RU status/entitlement по тому же server customer;
- offline/timeout не удаляет pending RU session и не запускает новый checkout;
- legacy cancellation fallback только явным flag + explicit repository.

Собирайте production chain через `RUBillingCompositionFactory`: registration
создаётся до Entitlement Engine, services — после engine через
`makeServices(refreshEntitlement:operationGate:)`. Всегда передавайте тот же
process-wide `BroadMonetizationServices.operationGate`: второй gate не защитит от
параллельной Apple/RU оплаты и persisted pending RU session. RU record app-wide,
но subject-bound; atomic insert/conditional clear не дают новой identity затереть
старую. При disabled feature остаются disabled adapters без RU source, как в
example.

[Special Offer](SpecialOffer.md) · [RU Billing](RUBilling.md)

## 11. Перенесите analytics и Adapty experiments

Создайте app destination для `MonetizationAnalyticsProtocol` и маппите только утверждённые typed events. Не пробрасывайте старый arbitrary parameters dictionary.

Используйте deduplication перед fan-out destinations. Не переносите legacy
randomizer, segment repository или собственный assignment cache: единственный
источник назначения обычных и cross-placement вариаций — Adapty SDK. Сохраните
одну стабильную Adapty identity и настройте связи placements в Dashboard.

В app analytics переносите только opaque variation attribution из typed
paywall/purchase contexts. При fallback сохраняйте requested и resolved placement,
но variation всегда считайте свойством resolved raw paywall. Cached purchase
разрешайте только после exact variation/index/SKU/fingerprint rehydration.

Paywall provider lifecycle не переносите в analytics destination. ViewModel
получает `services.trackPaywallEvent` и
`services.paywallPresentationLifecycle`; analytics destination не является
механизмом release provider handles.

Сравните старые и новые event counts на ручных fixtures, не добавляя PII/transaction identifiers.

[Experiments and analytics →](Experiments.md)

## 12. Переключение по вертикальным срезам

Рекомендуемый порядок rollout:

1. `settings` paywall на внутренней сборке;
2. main paywall + fallback;
3. purchase/restore с новым entitlement;
4. onboarding + initial paywall;
5. locked features/custom placements;
6. RU billing;
7. special offer и проверка Adapty experiment attribution.

Для каждого среза:

- включите новый route host feature flag;
- пройдите success/empty/error/offline/pending fixtures;
- оборвите сеть до, во время и после каждого financial boundary; неизвестный
  результат сначала reconciliate, не повторяйте списание автоматически;
- проверьте clean reinstall/login: Apple access, server token balance и RU status
  возвращаются без installation-local флагов;
- сравните analytics и entitlement outcomes;
- оставьте старый adapter как краткосрочный rollback;
- после стабильности удалите legacy screen + adapter вместе.

Не держите два активных purchase pipeline одновременно.

## Definition of done

- [ ] все UI routes используют один AppFlow;
- [ ] SDK initialization имеет явный порядок и timeout;
- [ ] ATT отсутствует в loader, review отсутствует в onboarding;
- [ ] placements typed, `.main` настроен и caches разделены;
- [ ] любой provider product отображается без фильтрации/сортировки;
- [ ] paywall tap/purchase без opacity/scale/dimming/flicker;
- [ ] purchase/restore/RU подтверждают entitlement перед premium;
- [ ] один app-wide financial gate, durable pending store и StoreKit recovery подключены;
- [ ] после переустановки Apple ownership, token balance и RU status восстанавливаются из authoritative sources;
- [ ] stable app account/subject связывает token и RU ledger между установками;
- [ ] offline/timeout дают конечный UI state; ambiguous financial result не запускается повторно до reconciliation;
- [ ] all configured entitlement combinations проверены;
- [ ] RU требует свежий `ru_pay = true` и RU region или русский первый системный язык;
- [ ] special offer отсутствует через `nil` там, где не нужен;
- [ ] remote config keys/defaults задокументированы;
- [ ] analytics typed, дедуплицированы и без PII;
- [ ] secrets отсутствуют в source/cache/logs;
- [ ] integration notes обновлены для host app;
- [ ] `./Scripts/lint.sh` проходит;
- [ ] `./Scripts/build.sh` проходит;
- [ ] ручные acceptance fixtures пройдены минимум на двух app configurations.

Test targets для platform migration не добавляются; риск закрывается строгими checks, полной сборкой и воспроизводимыми ручными сценариями.
