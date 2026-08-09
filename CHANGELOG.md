# Changelog

Все заметные изменения BroadApps iOS Platform фиксируются здесь до публикации
релиза. Проект пока не имеет Git tag; раздел `Unreleased` не является обещанием
production-ready версии.

## Unreleased

### Added

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
