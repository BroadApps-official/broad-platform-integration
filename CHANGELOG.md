# Changelog

Все заметные изменения BroadApps iOS Platform фиксируются здесь до публикации
релиза. Проект пока не имеет Git tag; раздел `Unreleased` не является обещанием
production-ready версии.

## Unreleased

### Added

- public logic-only `BroadOnboardingFlowHost` для полностью app-owned
  onboarding UI без дублирования переходов, завершения, invalid-state и ATT
  lifecycle;
- onboarding fixtures для 1/2/3/4/8 страниц, custom UI, `.disabled` и пустой
  конфигурации, а также обязательный `check_onboarding_contract.sh` без test
  targets;
- [Developer README](README.dev.md): понятная памятка по слоям Clean Architecture,
  добавлению сцен и use cases, UI-проверке, сложным пользовательским сценариям
  и проверке через агента или вручную;
- [Support Email guide](Documentation/SupportEmail.md): единая машиночитаемая
  форма письма, отдельная `(ukassa)`-маркировка RU-обращений, источники
  полей, очищенный support log, checklist и готовый промпт;
- [Usedesk guide](Documentation/Usedesk.md): запрос данных у ПМ, безопасный
  пример сообщения, CocoaPods GUI, вход `Настройки → Онлайн-чат`, app-owned
  сервис, backend-хранение user chat token, переустановка, обрыв сети и готовый
  промпт для Codex/Claude;
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
- provider-managed Remote Config contract для `special_offer` и показа
  `ru_pay`, семь безопасных launch fixtures и обязательная
  `check_remote_feature_contracts.sh` matrix без настоящих платежей.

### Changed

- карточка Special Offer в `BroadAppTemplate` теперь действительно проходит
  `subscription paywall → resolver → offer/main`, повторно резолвит новый
  presentation при каждом открытии и пишет обе презентации в общий process
  recorder аналитики;
- Debug refresh аналитики показывает spinner, время завершения и явное пустое
  состояние; статические контракты запрещают возврат к прямому открытию offer и
  отдельному невидимому recorder;
- build/final prompts требуют production-shape API contract smoke, полную
  матрицу initial-paywall/special-offer/Contact Us/analytics, два размера iPhone
  и явный `FUNCTIONAL REVIEW REQUIRED` checkpoint перед визуальной итерацией;
- документация уточняет, из payload какого placement читается
  `special_offer`, и отделяет fixture/source proof от app-owned безопасного
  load/show ожидаемого product ID без финансовых операций;
- `OnboardingConfiguration.pages` зафиксирован как единственный источник
  количества слайдов; три страницы `BroadAppTemplate` теперь явно обозначены
  только демонстрационным примером, а инструкции Codex/Claude требуют сначала
  определить страницы или задать разработчику один прямой вопрос;
- README получил единый визуальный язык: отдельную светлую/тёмную схему работы
  с reference и backend, цветные рамки для результата, предупреждений и
  запретов, карточки этапов вместо сухих текстовых стрелок и более заметные
  контрольные точки в инструкциях с агентом и без него;
- README теперь требует проверять в reference не только экраны и конфигурацию,
  но и backend-контракты: каждая функция нового приложения сопоставляется с
  реальной API-ручкой, а недостающий функционал до реализации согласуется с
  тимлидом-разработчиком или проектным менеджером;
- RU Billing gate приведён к production-правилу: обязательный
  provider-managed Adapty `ru_pay = true` и дополнительно регион iPhone `RU/RUS` **или** русский
  первый системный язык; App Store storefront больше не авторизует СБП/карту,
  а gate повторно проверяется непосредственно перед внешним checkout;
- стандартный Adapty repository теперь напрямую поддерживает Special Offer и
  RU feature gates без custom REST: platform cache по-прежнему не может включить
  их, raw products остаются во внутреннем registry, а Remote Config никогда не
  заменяет authoritative entitlement;
- README прошёл внутренний cold-read и аудит навигации: добавлена цветная схема
  двух способов работы, точные переходы по меню Codex/Claude и Xcode, единые
  критерии завершения шагов, раскрываемая матрица этапов и расширенный словарь
  проектных и платёжных терминов; независимый тест новым разработчиком остаётся
  отдельным handoff;
- README повторно выстроен как две полные параллельные инструкции: с
  Codex/Claude и без агента; в обеих явно пройдены исходные данные, создание
  проекта, Core/архитектура, UI, монетизация, восстановление, плохая сеть,
  проверка приложения и отдельная проверка платформы;
- сложные термины в README сохранены там, где они нужны разработчику, но теперь
  объясняются при первом использовании и собраны в коротком словаре; у каждого
  ручного этапа появился проверяемый результат «Готово, если»;
- Стартовая инструкция теперь берёт данные приложения из Kaiten, разрешает
  только fixture либо явно согласованные публичные client identifiers reference
  для безопасного load/show и фиксирует базовые правила Adapty для products,
  paywalls, placements и Remote Config; чужие provisioning/account/auth данные
  переносить запрещено;
- platform-owned AgentChecks больше не привязаны к номеру отдельного
  приложения: project-specific preflight/status и обязательный signed-device
  report заменены единым универсальным application integration contract;
- developer flow закреплён как `Team = None`, два iPhone Simulator и generic
  unsigned compile; доступный компании запуск на iPhone остаётся отдельным
  app-level evidence и не блокирует platform `PASS`;
- стандартный Remote Config распознаёт `ru_pay` и `auto_revenue_view` вместе с
  legacy aliases, а typed placements включают `pro_icon` и `CTR`;
- README теперь начинает работу с реального сценария команды: новое приложение
  строится поверх платформы; источник дизайна проверяется по Figma или
  согласованному no-code результату; reference разработчик сначала ищет в
  Kaiten/Git компании, а при необходимости запрашивает у
  тимлида-разработчика или ПМ; отдельные copy-paste инструкции объясняют
  проверку приложения и проверяющего агента платформы;
- главный README и связанные guides очищены от внутренней истории задачи,
  номеров reference-проектов и отчётного handoff-жаргона; RU screenshots теперь
  описывают конкретный RU Billing flow, а проверка видна как обязательный шаг в
  сценариях с агентом и без него;
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
