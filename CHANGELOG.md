# Changelog

Все заметные изменения BroadApps iOS Platform фиксируются здесь до публикации
релиза. Проект пока не имеет Git tag; раздел `Unreleased` не является обещанием
production-ready версии.

## Unreleased

### Added

- `RecoverCustomerAccessUseCase`: fresh-install/reinstall recovery для Apple и
  RU entitlements, server-authoritative token balance и RU subscription status;
- [Account Recovery guide](Documentation/AccountRecovery.md) с обязательной
  stable app identity, idempotent Apple/RU token ledger и launch-порядком;
- typed `NetworkFailureClassifier`, RU offline/timeout errors и немедленная
  остановка payment polling без очистки pending или повторного charge;
- [Network Interruptions guide](Documentation/NetworkInterruptions.md) с
  поведением для внезапного обрыва связи в каждой финансовой точке;
- независимый `BroadExtensions` product: Hex Color, custom font registration,
  keyboard dismiss и scoped interactive swipe-back;
- независимые `SubscriptionPurchaseManager` и `TokenPurchaseManager`; token
  flow сохраняет durable intent/evidence и передаёт verified StoreKit JWS в
  app-owned idempotent backend fulfillment;
- полный RU payment UI: СБП/карта, две обязательные consent-галочки,
  опциональный чек, валидация и повторное использование email, русские legal
  links; Apple скрывает RU-поля;
- `RUBillingManager`, загрузка management status и готовый
  `BroadRUSubscriptionManagementView` с paid-through датой и отменой;
- четыре реальные RU billing screenshots с iPhone Simulator, отдельные guides
  по Purchase Managers и BroadExtensions и единая карта документации;
- автоматический Codex review-and-fix cycle одной командой с постоянными
  `AGENTS.md` guardrails, management-approved full Mac access для Xcode,
  максимум тремя correction attempts, повторным независимым Xcode/live gate и
  понятным Markdown-отчётом;
- iPhone-only project policy с `TARGETED_DEVICE_FAMILY = 1` и автоматическим
  запретом iPad/Mac/visionOS configurations;
- локальные Swift/Clang/SwiftPM/SwiftFormat/Xcode package caches внутри
  `.build`, найденные первым автоматическим correction run;
- отдельный deterministic `agent_gate.sh`, который проверяет local engineering
  gate и компиляцию обеих tracked live Adapty configurations без запуска
  покупки/restore;
- [простая инструкция для разработчика](Documentation/AgentAutomation.md) с
  doctor-режимом, схемой работы, границами исправлений и troubleshooting;
- две схемы `BroadAppTemplateLiveAdapty5013` и
  `BroadAppTemplateLiveAdapty5109Codex`, которые загружают настоящие catalogs;
- tracked рабочие configurations с bundle, public SDK key, access level и
  placements 5013/5109Codex по требованию руководства;
- [platform handoff guide](Documentation/PlatformHandoff.md) с фактическим
  scope и ограничениями компании;
- provider-opaque `PaywallVariationID` в Apple purchase analytics;
- сохранение paywall presentation, variation и requested/resolved placement во
  внешнем RU checkout analytics, включая продолжение после cold launch;
- [матрица требований и готовности](Documentation/Traceability.md);
- актуальные Adapty-owned normal/cross-placement experiment contracts.
- [analytics guide](Documentation/Analytics.md), canonical shared pipeline и
  bounded typed recording fixture с явным refresh в `BroadAppTemplate`.

### Changed

- Стартовая инструкция теперь берёт данные приложения из Kaiten, поддерживает
  временную development-конфигурацию похожего live-приложения и фиксирует новые
  базовые правила Adapty для products, paywalls, placements и Remote Config;
- стандартный Remote Config распознаёт `ru_pay` и `auto_revenue_view` вместе с
  legacy aliases, а typed placements включают `pro_icon` и `CTR`;
- README теперь начинает работу с реального сценария команды: новое приложение
  строится поверх платформы, старые reference-проекты используются только как
  read-only продуктовый ориентир, а дизайн берётся из Figma либо из
  согласованного результата Claude Design/Pencil;
- английские пояснения в документации по архитектуре, запуску, монетизации,
  special offer и RU Billing
  переведены на простой русский язык; имена Swift API и JSON-полей сохранены без
  изменений, а старые ссылки на разделы RU Billing продолжают работать;
- `RUPaymentReturnOutcome.unavailable` теперь переносит typed safe `AppError`,
  чтобы host различал offline/timeout и показывал корректный Retry UI;
- live Adapty purchase/restore fail-before-charge по company policy, при этом
  activation/load/show и products остаются настоящими;
- Adapty paywall load budget стал конфигурируемым (`1...60` секунд, default
  `12`), чтобы один конечный timeout покрывал remote request и SDK fallback;
- готовность package отделена от последующей интеграции в production apps;
- Adapty SDK закреплён единственным assignment authority;
- remote `uiVariantID` описан только как renderer metadata;
- dependency graph теперь показывает прямую зависимость
  `BroadUIFlows → BroadCore`;
- onboarding-схемы показывают `1…N` слайдов и optional ATT;
- документация явно различает at-most-one provider show attempt и guaranteed
  analytics delivery.
- product selection analytics теперь сохраняет и уникальный occurrence ID, и
  catalog product/SKU ID.

### Removed

- обязательный sensitive-data scanner из local gate;
- необязательный unsigned `.xcarchive`: для package handoff достаточно
  generic-device compile, архив и `.ipa` не создаются;
- неиспользуемый generic experiment assignment coordinator, repository/use-case
  contracts, segment models и synthetic assignment/show events;
- dead experiment cohort key из remote config;
- no-op Adapty analytics adapter, который не отправлял ни одного события.

### Fixed

- двойной `.disabled(!isEnabled)` на строке продукта paywall;
- потеря variation attribution между paywall selection и purchase/RU return.

## 1.0.0

Platform package передаётся после успешного единого agent review-and-fix cycle.
Интеграцию в реальные приложения позднее выполняют app-команды; она не является
критерием готовности package.
