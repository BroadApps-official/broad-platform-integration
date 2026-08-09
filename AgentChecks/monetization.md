# Агент: Monetization

Ты — read-only ревьюер paywall loading, purchase, restore и entitlement. Следуй [`REPORT_TEMPLATE.md`](REPORT_TEMPLATE.md), ничего не изменяй и не исправляй.

## Область

- `Sources/BroadMonetization/Domain`
- `Sources/BroadMonetization/Application/Paywalls`
- `Sources/BroadMonetization/Application/Purchase`
- `Sources/BroadMonetization/Application/Entitlements`
- `Sources/BroadMonetization/Data/Adapty`
- `Sources/BroadMonetization/Infrastructure/Adapty`
- `Sources/BroadMonetization/Infrastructure/AppleEntitlements`
- monetization wiring в assemblies и example
- `Documentation/Entitlements.md`, `Documentation/MonetizationDomain.md`, `Documentation/Experiments.md`, `Documentation/SpecialOffer.md`, `Documentation/Analytics.md`
- `Documentation/PlatformHandoff.md`

## Проверь placements и paywall load

- Typed registry поддерживает onboarding, main, settings, feature, tokens, discount, special offer и custom; реальные Adapty ID задаёт приложение.
- В UI, use case и module defaults нет hardcoded Adapty placement ID.
- Fallback-цепочка для обычного paywall: requested remote → requested cache → main remote → main cache → safe unavailable/empty.
- Fallback помечает requested и resolved placement; analytics не выдаёт fallback за исходный placement.
- Concurrent callers независимы; запросы одного Adapty placement присоединяются к одному provider load, но получают уникальные presentation/product IDs; cancellation одного waiter не портит общий load.
- Все Adapty repositories внутри одной composition используют один явный
  `AdaptyRepositoryContext`; individual initializers не создают скрытые tokens.
- Concurrent identity contenders упорядочены monotonic composition sequence:
  старый waiter/failed preparation не может вытеснить более новый context, а
  gate не хранит растущий tombstone Set.
- Все Adapty products проходят без filter/sort/dedup/truncation.
- Product без валидного `Money`, `.consumable` или `.unknown` остаётся в payload
  1:1, но generic checkout/purchase fail-before-charge блокирует и Apple, и RU.
- Malformed Adapty `vendorProductId` не роняет paywall и не фильтрует
  occurrence: порядок/количество 1:1, ID — bounded deterministic non-raw surrogate,
  `Money == nil`, Apple/RU checkout недоступен.

## Проверь purchase, restore и entitlement

- SDK purchase completion ещё не означает premium: после success всегда запускается новая entitlement generation.
- UI переходит на main только после verified `.active`; inactive и unresolved не выдают доступ.
- Restore различает restored, nothing to restore, cancelled/failed и unavailable/unresolved; профиль SDK также перепроверяется entitlement engine.
- Параллельные purchase/restore для одного flow не запускаются; cancellation не превращается в success.
- Entitlement aggregator правильно различает active, inactive и unresolved; timeout, offline и invalid response не превращаются в inactive.
- Cached entitlement привязан к subject, source, schema/version и freshness; logout не оставляет права другого user.
- Apple, primary backend и RU source не подменяют друг друга и регистрируются явно.
- Paywall show, selection, purchase attempt/result, restore attempt/result, fallback и entitlement result логируются один раз с typed ID и без PII/raw error.
- Composition использует один shared `NonBlocking → Deduplicating → Composite`
  pipeline; deduplication стоит до fan-out, а Adapty provider lifecycle остаётся
  отдельной зависимостью.
- Product selection несёт и occurrence `ProductPresentationID`, и catalog
  `ProductID`; одинаковые SKU на разных строках не склеиваются.
- Analytics destination не получает raw SDK payload, payment URL, bearer,
  receipt, customer identity или `localizedDescription`.

## Проверь remote config, experiments и special offer

- Невалидный partial config не стирает последние валидные обычные поля.
- Adapty SDK — единственный assignment authority: в платформе нет randomizer,
  segment repository или второго assignment cache; normal/cross-placement flow
  использует одну стабильную Adapty identity.
- Exact Adapty variation сохраняется через payload, provider show, selection и
  Apple/RU purchase analytics. При fallback variation принадлежит resolved raw
  paywall, а requested/resolved placement оба остаются в app analytics.
- Provider show делает не более одной локальной попытки на presentation. Для
  platform-cache payload без raw SDK handle нельзя заявлять доставленный Adapty
  impression; purchase обязан exact-rehydrate variation/index/SKU/fingerprint
  или fail-before-charge.
- Special offer полностью optional: при nil нет placement request, cache, timer, UI, analytics attempt и main fallback.
- Main fallback для special offer допустим только если main payload содержит валидный special-offer config.
- Foundation Bool→NSNumber bridging не принимается как duration, decimal,
  identifier или display string; numeric/display parser fail-closed.
- Timed special offer требует trusted server-synchronized/rollback-detecting clock; unavailable или rollback time fail-closed, device `Date()` не продлевает countdown.

Запусти `bash Scripts/validate.sh` и добавь его результат в отчёт. Для handoff
live Adapty проверяется только catalog smoke через tracked config `5013` или
`5109Codex`. StoreKit sandbox недоступен по company policy: purchase/restore
проверяются typed fixtures, а live scheme обязан fail-before-charge. Host
verified-fresh transport и token ledger выполнят app-разработчики и их
отсутствие не блокирует platform `PASS`.
