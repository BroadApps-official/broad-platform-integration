# Матрица готовности BroadApps iOS Platform

Этот документ связывает исходные требования к платформе с реализацией и честно
отделяет готовность package от будущей интеграции конкретного приложения.
Матрица относится **только** к `BroadAppsIOSPlatform`; reference repositories
используются read-only для local Adapty smoke и не изменяются.

## Как читать статусы

| Статус | Значение |
|---|---|
| `IMPLEMENTED` | Контракт и production-код находятся в package |
| `FIXTURE_VERIFIED` | Поведение воспроизводится локальным example-сценарием |
| `REQUIRES_HOST` | Нужны app-owned IDs, тексты, credentials, backend или composition |
| `REQUIRES_LIVE_EVIDENCE` | Нужен разрешённый live provider/backend smoke без финансовой операции |
| `PARTIAL` | Безопасная часть готова, но заявлять полный продуктовый сценарий нельзя |
| `OUT_OF_SCOPE` | Пункт сознательно передан app-разработчикам или исключён company policy |
| `RELEASE_PENDING` | Локальная реализация есть, но Git/CI/tag/release ещё не созданы |

`IMPLEMENTED` не означает готовую интеграцию приложения. Platform handoff
фиксируется для exact source snapshot по
[Platform Handoff](PlatformHandoff.md).

## Требования → код → проверка

| Требование | Где реализовано | Как проверить | Статус |
|---|---|---|---|
| Три независимых модуля, Clean Architecture, MVVM, SOLID и DI | [Package.swift](../Package.swift), [BroadCore](../Sources/BroadCore), [BroadMonetization](../Sources/BroadMonetization), [BroadUIFlows](../Sources/BroadUIFlows) | [Architecture](Architecture.md), [ADR-0001](ADR/0001-module-boundaries.md), `Scripts/check_architecture.sh` | `IMPLEMENTED` |
| Единый code style и строгие базовые проверки без test targets | [.swiftformat](../.swiftformat), [.swiftlint.yml](../.swiftlint.yml), [Scripts](../Scripts) | `format.sh --lint`, `lint.sh`, `build.sh`, `release_gate.sh` | `IMPLEMENTED` |
| Стандартный launch/bootstrap и порядок SDK | [Bootstrap Application](../Sources/BroadCore/Application/Bootstrap), [ActivateMonetizationUseCase](../Sources/BroadMonetization/Application/Monetization/ActivateMonetizationUseCase.swift) | [Bootstrap](Bootstrap.md), bootstrap arguments example | `IMPLEMENTED`, `FIXTURE_VERIFIED` |
| Единый cache/offline/degraded contract | [Cache](../Sources/BroadCore/Data/Cache), [LoadableState](../Sources/BroadCore/Domain/States/LoadableState.swift), monetization caches | [Caching & Offline](CachingAndOffline.md), seed/stale/offline fixtures | `IMPLEMENTED`, `FIXTURE_VERIFIED` |
| Сквозной launch → onboarding → paywall → purchase/restore → main | [AppFlow](../Sources/BroadUIFlows/Application/AppFlow), [BroadAppFlowView](../Sources/BroadUIFlows/Presentation/AppFlow/BroadAppFlowView.swift), [Example](../Examples/BroadAppTemplate) | [AppFlow](AppFlow.md), example launch arguments | Локальный flow — `FIXTURE_VERIFIED`; StoreKit sandbox — `OUT_OF_SCOPE` |
| Configurable onboarding | [Onboarding](../Sources/BroadUIFlows/Presentation/Onboarding) | [Onboarding & ATT](OnboardingAndATT.md), 1…N page configurations | `IMPLEMENTED`; app copy/media — `REQUIRES_HOST` |
| ATT только после появления первого onboarding-слайда, никогда в loader | [OnboardingViewModel](../Sources/BroadUIFlows/Presentation/Onboarding/OnboardingViewModel.swift), [Tracking adapter](../Sources/BroadCore/Infrastructure/Tracking) | [ADR-0002](ADR/0002-att-and-rate-us.md), architecture guard | Код и fixture wiring — `IMPLEMENTED`; real-host run выполнят app-разработчики |
| Rate Us разрешён вне onboarding, но отсутствует внутри onboarding | Onboarding footer и flow не импортируют review API; guard запрещает review-вызов в onboarding | [ADR-0002](ADR/0002-att-and-rate-us.md), source scan | `IMPLEMENTED`; app-owned Rate Us вне onboarding — `REQUIRES_HOST` |
| Общие loader/error/empty/stale/retry состояния | [BroadCore state](../Sources/BroadCore/Domain/States), [Loadable UI](../Sources/BroadUIFlows/Presentation/Loadable) | [Loadable State](LoadableState.md), [Loadable UI](LoadableUI.md) | `IMPLEMENTED`, `FIXTURE_VERIFIED` |
| Loader/error/retry непосредственно на paywall | [Paywall presentation](../Sources/BroadUIFlows/Presentation/Paywall) | [Paywall UI](PaywallUI.md), empty/failure/retry fixtures | `IMPLEMENTED`, `FIXTURE_VERIFIED` |
| Любое количество provider products, порядок и duplicates 1:1, без filter/sort/dedup | [Adapty product mapping](../Sources/BroadMonetization/Data/Adapty/AdaptyPaywallRepository+ProductMapping.swift), [PaywallPayload](../Sources/BroadMonetization/Domain/Paywalls/PaywallPayload.swift) | 0/1/2/12, duplicate и malformed fixtures; architecture source guard | `IMPLEMENTED`, `FIXTURE_VERIFIED` |
| UI не ломается на malformed/unknown/consumable product | [MonetizationProduct](../Sources/BroadMonetization/Domain/Products/MonetizationProduct.swift), purchase eligibility guards | [Monetization Domain](MonetizationDomain.md), [Paywall UI](PaywallUI.md) | Безопасный display/fail-before-charge — `IMPLEMENTED`; app-owned token ledger — `OUT_OF_SCOPE` |
| Product row и CTA без dimming/opacity/scale/pressed flicker | [BroadNoPressEffectButtonStyle](../Sources/BroadUIFlows/Presentation/Paywall/BroadNoPressEffectButtonStyle.swift), paywall controls | Static guard + Simulator fixture | `IMPLEMENTED`, `FIXTURE_VERIFIED`; physical device — `OUT_OF_SCOPE` |
| Typed placements: onboarding/main/settings/feature/tokens/discount/custom | [PlacementID](../Sources/BroadMonetization/Domain/Identifiers/MonetizationIdentifiers.swift), [AdaptyPlacementRegistry](../Sources/BroadMonetization/Infrastructure/Adapty/AdaptyPlacementRegistry.swift) | [Monetization](Monetization.md), [Platform Handoff](PlatformHandoff.md) | `IMPLEMENTED`; working IDs 5013/5109Codex хранятся в tracked configs |
| Общий provider-neutral fallback на `main` | [LoadPaywallUseCase](../Sources/BroadMonetization/Application/Paywalls/LoadPaywallUseCase.swift), [repository protocol](../Sources/BroadMonetization/Domain/Repositories/MonetizationRepositoryProtocols.swift) | [Fallback diagram](Diagrams/paywall-fallback.mmd), requested/resolved analytics | `IMPLEMENTED`; live provider/cache — `REQUIRES_LIVE_EVIDENCE` |
| Typed remote config и безопасные aliases | [Remote models](../Sources/BroadMonetization/Domain/Paywalls/RemotePaywallConfiguration.swift), [parser](../Sources/BroadMonetization/Infrastructure/RemoteConfig/RemotePaywallConfigurationParser.swift) | [Remote Config](RemoteConfig.md) | `IMPLEMENTED`; positive financial gate требует host-owned fresh provenance |
| Special offer может существовать или полностью отсутствовать | [ResolveSpecialOfferUseCase](../Sources/BroadMonetization/Application/SpecialOffers/ResolveSpecialOfferUseCase.swift) | [Special Offer](SpecialOffer.md), enabled/absent fixtures, optional `5013` placement | Contract — `IMPLEMENTED`; app campaign rollout — `OUT_OF_SCOPE` |
| Единый Adapty/StoreKit слой: paywall, purchase, restore, entitlement | [Adapty adapters](../Sources/BroadMonetization/Data/Adapty), [Apple entitlement adapters](../Sources/BroadMonetization/Infrastructure/AppleEntitlements) | [Monetization](Monetization.md), [Entitlements](Entitlements.md), company-policy fixtures | Код — `IMPLEMENTED`; live Adapty catalog — local smoke; StoreKit sandbox — `OUT_OF_SCOPE` |
| Обычные и cross-placement эксперименты | Adapty SDK — единственный assignment authority; [PaywallVariationID](../Sources/BroadMonetization/Domain/Identifiers/MonetizationIdentifiers.swift), exact raw paywall/product lifecycle | [Experiments](Experiments.md), normal/cross-placement/fallback/cache checklist | Контракт — `IMPLEMENTED`; Dashboard/identity/live attribution — `REQUIRES_HOST`, `REQUIRES_LIVE_EVIDENCE` |
| Variation проходит в Apple и внешнюю RU conversion analytics | [analytics contexts](../Sources/BroadMonetization/Domain/Analytics/MonetizationAnalyticsEvent.swift), [pending RU store](../Sources/BroadMonetization/Data/RUBilling/PendingRUCheckoutStore.swift) | Purchase + cold-launch RU return scenarios | `IMPLEMENTED`; analytics export — `REQUIRES_HOST` |
| Общий RU billing adapter, storefront gate, catalog, Safari return, polling, cancel | [RU Application](../Sources/BroadMonetization/Application/RUBilling), [RU Infrastructure](../Sources/BroadMonetization/Infrastructure/RUBilling) | [RU Billing](RUBilling.md), [ADR-0004](ADR/0004-ru-billing-fallback.md) | Fail-closed contract — `IMPLEMENTED`; реальный backend/payment — `OUT_OF_SCOPE` для package handoff |
| Единая typed analytics без PII/raw errors | [analytics domain](../Sources/BroadMonetization/Domain/Analytics), [analytics adapters](../Sources/BroadMonetization/Infrastructure/Analytics), [example recorder](../Examples/BroadAppTemplate/BroadAppTemplate/Infrastructure/Analytics) | [Analytics](Analytics.md), `-analytics-fixture`, [Security](Security.md), agent review/export allow-list | Pipeline и локальный recorder — `IMPLEMENTED`, `FIXTURE_VERIFIED`; production destination/export — `REQUIRES_HOST` |
| Автоматическая проверка агентом | [Automation prompt](../AgentChecks/AUTOMATION_PROMPT.md), [agent script](../Scripts/agent_review_and_fix.sh), [agent gate](../Scripts/agent_gate.sh) | [Current status](../AgentChecks/STATUS.md), `./Scripts/agent_review_and_fix.sh` | `IMPLEMENTED` — один агент проверяет, исправляет и повторно подтверждает полный gate |
| Developer-first README, схемы, GIF и профильные guides | [README](../README.md), [README assets](Assets/README), эта матрица и документация | Link/XML/GIF validation + developer walkthrough | Документация — `IMPLEMENTED`; настоящая запись Simulator/device — `PARTIAL` |
| Внедрение в текущие приложения | Platform даёт migration/handoff contracts, но не меняет reference projects | [Migration Guide](MigrationGuide.md), [Platform Handoff](PlatformHandoff.md) | `OUT_OF_SCOPE` — выполнят app-разработчики после передачи |
| Git repository, CI, tag и BroadApps iOS Platform 1.0 | Package и local release gate готовы | Git remote/workflow/tag/release | `RELEASE_PENDING` |
| Не писать unit/UI test targets | [Package.swift](../Package.swift) содержит только library products; validate запрещает `Tests/` и test targets | `Scripts/validate.sh` | `IMPLEMENTED` — это согласованная policy, а не дефект |

## Границы текущей передачи

Platform handoff подтверждается единым автоматическим agent cycle, локальными
fixtures и двумя tracked Xcode configurations для `5013` и `5109Codex`.
Интеграция конкретных приложений и их release pipeline выполняются отдельно.

Внедрение в реальные приложения, StoreKit sandbox, physical-device
VoiceOver/Dynamic Type, distribution-signed `.ipa` и host attestations не
являются требованиями платформы. Первое выполнят app-разработчики позднее,
остальное исключено текущей company policy.

## Kaiten

9 августа 2026 года поиск через подключённый Kaiten по названию платформы и
формулировкам исходной задачи не нашёл отдельной карточки/эпика. Поэтому README
не содержит выдуманной ссылки. Когда карточка будет создана или передан её ID,
сюда и в README нужно добавить прямую ссылку на epic, integration cards и
production checklist.
