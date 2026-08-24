# Changelog

Все заметные изменения BroadApps iOS Platform фиксируются здесь до публикации
релиза. Проект пока не имеет Git tag; раздел `Unreleased` не является обещанием
production-ready версии.

## Unreleased

### Added

- принят [ADR-0006](Documentation/ADR/0006-federated-public-repositories.md):
  четыре Swift products переносятся в отдельные публичные repositories,
  а integration/docs получают свои repositories;
- [план федерации](Documentation/FederatedRepositories.md),
  [release policy](Documentation/ModuleReleasePolicy.md) и машиночитаемый
  `Compatibility/current.yml` фиксируют ownership, SemVer, порядок release
  снизу вверх и acceptance каждого шага;
- публичный [BroadApps iOS Docs](https://broadapps-ios-docs.nkhsnv.chatgpt.site)
  с поиском по Markdown, открытым чтением и `Edit this page`;
- README превращён из монолитного справочника в короткую navigation-точку;
  шесть воспроизводимых light/dark схем объясняют выбор модулей,
  repositories, миграцию, release, cross-repo changes и docs pipeline;
- `BroadExtensions 1.0.0` вынесен в public repository с сохранением Git-истории,
  standalone Gallery, executable production-type probe, DocC, public API report,
  pinned tools, clean-runner CI и release workflow;
- integration example теперь собирает exact tag `BroadExtensions 1.0.0`,
  а дублирующие production sources удалены из integration checkout;
- `BroadCore 1.0.0` вынесен в public repository с сохранением Git-истории,
  standalone iPhone sandbox, production-type probe, privacy-manifest check,
  DocC, public API report, clean-runner CI и release workflow;
- integration package и example собирают exact tag `BroadCore 1.0.0`;
  локальная копия Core удалена, а privacy acceptance проверяет
  manifest из собранного remote package;
- `BroadMonetization 1.0.0` вынесен в public repository с сохранением
  Git-истории, отдельным iPhone sandbox, DocC/public API report и исполняемыми
  Special Offer/Adapty contract probes;
- integration package, `BroadUIFlows` и host example собирают exact tag
  `BroadMonetization 1.0.0`; локальная копия production sources удалена,
  а cross-module gate проверяет точный release, lockfile и UI/host behavior;
- `BroadUIFlows 1.0.0` вынесен в public repository с сохранением Git-истории,
  публичной iPhone Gallery реальных onboarding/loadable/paywall/Special Offer/
  token/RU-management экранов, DocC/public API report и static UI contracts;
- integration package и host example подключают `BroadUIFlows 1.0.0` напрямую;
  локальная копия UI production sources удалена, поэтому UI review, release и
  модификация выполняются в небольшом module repository, а integration gate
  проверяет совместимость всех четырёх exact releases без обязательного umbrella;
- integration checkout получил clean-runner GitHub Actions workflow, локальную
  checksum-проверенную установку SwiftLint/XcodeGen и отдельный Xcode lockfile;
  это делает exact-набор воспроизводимым без заранее установленных Homebrew tools;
- публичный `broad-platform-integration` прошёл полный clean-runner gate, а
  public clone каждого из четырёх tags отдельно прошёл свой `module_gate.sh`;
  compatibility catalog поэтому опубликован как проверенный platform set `1.0.0`;

### Почему платформа делится на repositories

Цель — уменьшить область review и release. Host app подключает любой
нужный модуль напрямую; обязательного `BroadPlatform` нет. Integration
repository нужен для проверенных exact versions и целостного example, а не
как обязательная runtime dependency.

Документы не удаляются из Git: Markdown/DocC остаются публично
редактируемыми, а отдельный сайт добавляет навигацию и поиск. По решению
владельца unit tests/test targets/XCTest не добавляются; их место занимают
static contracts, builds, executable probes и iPhone sandboxes.

- универсальный staged workflow создания host app: отдельные preflight,
  Integration Plan, skeleton, vertical-slice, functional, visual и acceptance
  prompts с обязательными developer checkpoints;
- копируемый `AppIntegrationPlan.md`, обезличенный пример feature-level
  `BLOCKED` и documentation gate, не позволяющий вернуть устаревший монолитный
  build prompt;
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
  сервис, backend-источник user chat token, account-scoped Keychain cache с
  pending sync, переустановка, обрыв сети и готовый промпт для Codex/Claude;
- `RecoverCustomerAccessUseCase`: fresh-install/reinstall recovery для Apple и
  RU entitlements, server-authoritative token balance и RU subscription status;
- [Account Recovery guide](Documentation/AccountRecovery.md) с обязательной
  stable app identity, account-scoped balance snapshot, duplicate-safe
  Apple/RU fulfillment и launch-порядком;
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
- пять реальных RU billing screenshots с iPhone Simulator, отдельные guides
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
- раздельные Remote Config capability для provider-managed `special_offer` и
  verified-fresh `ru_pay`, девять безопасных launch fixtures и обязательная
  `check_remote_feature_contracts.sh` matrix без настоящих платежей.
- typed Dashboard-generated Adapty fallback registration до SDK activation;
  файл остаётся provider payload для paywall/Special Offer, но не даёт
  verified freshness для `ru_pay`;
- process-local tri-state `ru_pay` для Debug-проверок и typed availability
  diagnostics; Release UI не содержит force-control, default store
  fail-closed следует Adapty, а host разблокирует override только
  под `#if DEBUG`, включая custom-named Debug configurations.

### Ответы на замечания: token recovery и Usedesk

#### 1. «Не проще ли после входа просто получать токены по backend-аккаунту?»

**Ответ:** да. Обычное восстановление после входа теперь описано как один
account-scoped read: приложение вызывает, например, `GET /me/token-balance`,
backend определяет пользователя по server authorization и возвращает полный
актуальный `TokenBalanceSnapshot`. Клиент не восстанавливает сумму локально и
не отправляет backend список StoreKit transaction ID или RU checkout ID.

**Почему transaction/checkout ID всё равно нужен:** это вход не операции
восстановления, а операции начисления. Если backend уже начислил токены, но
ответ потерялся, приложение повторно отправит то же доказательство покупки. Без
unique operation ID повтор превратится во второе начисление. При этом один
пользователь вправе несколько раз купить один и тот же пакет, поэтому
дедупликация только по `userID` или product ID также неверна.

Минимальная корректная backend-модель не требует event sourcing:

1. таблица текущего баланса по app account;
2. таблица обработанных покупок с unique constraint по
   `(provider, environment, externalOperationID)`;
3. одна атомарная операция: зарегистрировать ещё не обработанный ID, начислить
   баланс и вернуть полный snapshot; для уже обработанного ID вернуть текущий
   snapshot без повторного начисления.

**Что изменено в платформе:**

- [Account Recovery](Documentation/AccountRecovery.md) теперь визуально и
  текстом разделяет `login → balance read` и `purchase → exactly-once credit`;
- [Purchase Managers](Documentation/PurchaseManagers.md),
  [Token Paywall](Documentation/TokenPaywall.md) и
  [RU Billing](Documentation/RUBilling.md) используют ту же модель;
- комментарии `RecoverTokenAccountUseCaseProtocol` требуют полный snapshot
  авторизованного account без списка purchase ID;
- комментарии `TokenFulfillmentRepositoryProtocol` оставляют transaction ID
  только на duplicate-safe fulfillment boundary;
- README, developer checklist, Integration Plan и Project Delivery одинаково
  объясняют контракт разработчику и агенту;
- documentation gate запрещает вернуть старую формулировку, в которой ledger
  выглядит обязательным входом обычного recovery.

**Граница ответственности:** платформа даёт модели, flow и требования. Backend
endpoint, авторизация, таблицы баланса и processed operations принадлежат
конкретному host-приложению. Локальный fixture не считается доказательством их
production-готовности.

#### 2. «Почему Usedesk token не хранить в Keychain как deviceId/userId?»

**Ответ:** Keychain нужен, но не как единственный источник и не под device ID.
Для авторизованного приложения принята гибридная модель:

```text
backend текущего app account = источник chat token между установками/устройствами
account-scoped Keychain      = защищённый локальный cache и pending sync
device ID                    = не является identity пользователя или переписки
```

**Почему Keychain-only недостаточен:** локальная запись может помочь на этом
устройстве и пережить обычный offline-сценарий, но не связывает историю с тем же
аккаунтом на другом устройстве или платформе. Device ID, наоборот, связывает
чат с установкой/устройством и ломает account recovery. `userID` допустим как
namespace Keychain-записи, однако backend endpoint всё равно должен определять
account по своей authorization session, а не доверять произвольному ID из
query/body.

**Что изменено в платформе:**

- [Usedesk guide](Documentation/Usedesk.md) получил схему
  `backend source → Keychain cache → pending backend sync`;
- новый repository contract отдельно описывает загрузку, сохранение callback
  token и деактивацию token при logout/account switch;
- callback сначала сохраняет token в Keychain точного account, затем делает
  backend sync; temporary error возвращает `pendingBackendSync` и не
  проглатывается через `try?`;
- backend token имеет приоритет, а fallback из Keychain разрешён только для
  того же current account;
- при logout active/in-memory token очищается сразу; незавершённый encrypted
  pending sync остаётся недоступным другим аккаунтам и может продолжиться
  только после повторного входа в исходный account;
- Security, README, developer/agent checklist и app integration contract
  запрещают device ID как chat identity и raw token в Console/analytics;
- документационный gate проверяет наличие `pendingBackendSync`, logout boundary
  и `isSaveTokensInUserDefaults: false`, а также запрещает молчаливый `try?`.

**Допустимое исключение:** Keychain-only можно выбрать только как явное
продуктовое ограничение device-bound чата. В таком варианте приложение не может
обещать восстановление истории на другом устройстве/платформе. Базовый contract
BroadApps для account-based приложений остаётся `backend + account-scoped
Keychain cache`.

**Граница ответственности:** платформа не добавляет Usedesk в каждое приложение
автоматически. Host app подключает CocoaPods SDK, authenticated backend
repository и точные Keychain service/account scopes только если ПМ подтвердил
наличие Usedesk в проекте.

### Changed

- account recovery теперь явно загружает полный token balance по
  авторизованному app account; StoreKit transaction ID и RU checkout ID
  остались только защитой начисления от дублей, а не обязательным входом
  восстановления;
- Usedesk contract уточнён до гибридной модели: backend — источник истории
  между устройствами, account-scoped Keychain — cache и durable pending sync;
  device ID запрещён как user identity, ошибка синхронизации не проглатывается;
- staged app workflow теперь полностью покрывает happy path, partial backend,
  missing design, `N/A`, existing app, новый чат и resume после `BLOCKED`; пять
  пар README-схем синхронизированы с Integration Plan, одним vertical slice,
  developer checkpoints и acceptance;
- корневой README прошёл отдельный readability-аудит: плотные объяснения
  преобразованы в короткие таблицы, списки и GitHub callouts, глубокие
  platform-отчёты свёрнуты, а устаревшее название единого финального prompt
  заменено на отдельные visual review и acceptance;
- README, developer guide, app integration contract и Project Delivery теперь
  одинаково ведут разработку с агентом и без него: сначала доказанные
  screen/backend/ownership contracts, затем каркас и один вертикальный срез за
  раз; номер конкретного приложения и его execution status не хранятся в
  platform-owned отчётах;
- README и все integration/acceptance guides уточняют, что `false` —
  baseline только для неподключённой feature: рабочий verified-fresh
  `ru_pay = true` нельзя затирать шаблонным JSON;
- runtime-проверка получила `stream_example_logs.sh`: helper выбирает booted
  iPhone Simulator, фильтрует safe OSLog по subsystem и понятно объясняет выбор
  UDID; README разделяет AppFlow `[FLOW]` и catalog-only analytics/experiment
  события;
- debug-значение AppFlow теперь отдельно показывает стабильный route и текущую
  presentation, поэтому resolver и второй Special Offer paywall не выглядят как
  обычный initial paywall;
- manual acceptance исправлен для `unresolved`/timeout: обычный main доступен,
  premium закрыт, а pending не превращается в успех; terminal PASS теперь явно
  ограничен локальным platform/example scope;
- README получил приложенную пару design-reference экранов и явную механику
  `subscription paywall → крестик без покупки → resolver → Special Offer`;
  confirmed purchase/restore первого paywall обходит downsell;
- architecture gate теперь отдельно защищает порядок initial и catalog Special
  Offer flow и не позволяет completion первого paywall открыть offer;
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
  verified-fresh `ru_pay = true` и дополнительно регион iPhone `RU/RUS` **или** русский
  первый системный язык; App Store storefront больше не авторизует СБП/карту,
  а gate повторно проверяется непосредственно перед внешним checkout;
- стандартный Adapty repository теперь напрямую поддерживает Special Offer
  без custom REST; RU capability остаётся отдельной и strict, raw products остаются
  во внутреннем registry, а Remote Config никогда не
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

- Special Offer больше не блокируется provenance/state/clock до показа:
  штатный Adapty flow сначала загружает все products, затем `special_offer = true`
  выдаёт presentation authorization, а таймер остаётся визуальным 24-часовым циклом;
- RU Billing capability отделена от Special Offer и снова требует
  `.verifiedFreshRemote`; provider cache не включает `ru_pay`;
- двойной `.disabled(!isEnabled)` на строке продукта paywall;
- потеря variation attribution между paywall selection и purchase/RU return.

#### Почему Special Offer исправлен именно так

**Корневая причина.** Стандартный `AdaptyPaywallRepository` не может доказать,
что SDK получил именно свежий network response: Adapty вправе прозрачно вернуть
свой cache или Dashboard-generated fallback. Поэтому repository корректно
помечает payload как `.providerCacheFallbackPossible`. Раньше Special Offer и
RU Billing использовали общий freshness-gate, допускавший только
`.verifiedFreshRemote`. В результате `RemotePaywallConfiguration.qualified`
удалял `special_offer`, а дополнительные state/clock-проверки resolver могли
остановить flow ещё до завершения обычной загрузки и разбора подписок.

**Новый контракт загрузки.** Special Offer использует штатную последовательность
Adapty: `getPaywall -> getPaywallProducts -> 1:1 mapping -> raw product registry`.
Только после получения paywall и всех его products resolver проверяет
`special_offer == true` и presentation lifecycle. Это сохраняет точное
соответствие выбранного platform product исходному `AdaptyPaywallProduct`, не
добавляет dictionary/dedup и не требует custom REST-транспорта.

**Почему provider payload теперь достаточен.** `special_offer` — управляемый
Adapty флаг выбора второй презентации, а не финансовое доказательство и не
entitlement. Поэтому текущий provider payload, включая возможный SDK
cache/fallback, вправе разрешить Special Offer. Payload, восстановленный из
собственного platform cache, и legacy payload по-прежнему не могут заново
включить офер.

**Почему убраны expiration и trusted clock.** По продуктовому контракту таймер
Special Offer является только визуальной механикой: он локально показывает
`24:00:00 -> 00:00:00`, затем начинает новый такой же цикл. Ноль не закрывает
paywall, не отменяет checkout и не меняет доступность офера. Старые duration,
state repository и clock сохранены только для source/decoding compatibility;
они больше не участвуют в runtime-решении. Предпочтительный initializer
`ResolveSpecialOfferUseCase` принимает только load use case и presentation
lifecycle.

**Почему RU Billing не использует то же разрешение.** `ru_pay` открывает
финансовый способ оплаты и остаётся fail-closed: положительный флаг действует
только из host-controlled `.verifiedFreshRemote` payload. Ни Adapty SDK cache,
ни Dashboard fallback, ни platform cache не авторизуют RU Billing. Таким
образом, восстановление Special Offer не ослабляет финансовую границу,
проверку entitlement или финальный checkout gate.

## 1.0.0

Platform package передаётся после успешного единого agent review-and-fix cycle.
Интеграцию в реальные приложения позднее выполняют app-команды; она не является
критерием готовности package.
