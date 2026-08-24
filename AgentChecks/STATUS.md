# Последняя подтверждённая проверка платформы

## Результат

`PASS` — полный local gate, clean-runner integration CI и clean-clone module
gates прошли 25 августа 2026 года. Четыре public modules выпущены как `1.0.0`,
host example подключает нужные products напрямую, а integration repository
фиксирует проверенный exact-набор без обязательного umbrella.

Scope результата — только `BroadAppsIOSPlatform` и `BroadAppTemplate`. Он не
переносится автоматически ни на одно приложение, созданное поверх платформы.

## Что подтверждено

- правила, архитектура, privacy, documentation links и README assets;
- публичные `BroadCore`, `BroadExtensions`, `BroadMonetization` и
  `BroadUIFlows` по tag `1.0.0`, каждый из clean clone;
- `broad-platform-integration` на clean `macos-15` runner;
- SwiftFormat и SwiftLint без нарушений;
- Swift Package и iPhone example в Debug/Release Simulator;
- Release generic iOS device compile без подписи;
- две live Adapty configurations только компиляцией, без финансовых действий;
- полная fixture-матрица AppFlow, entitlement, special offer и token flow;
- карточка Special Offer проходит subscription paywall → close без покупки →
  resolver → offer; confirmed completion первого paywall обходит offer; каждый
  повторный вход получает новую presentation authorization, а события обоих
  paywall попадают в общий process recorder;
- README показывает приложенную пару design-reference экранов и явно отделяет
  app-owned визуал от обязательной последовательности переходов;
- Debug refresh аналитики показывает spinner, timestamp и явное empty state;
- девять карточек каталога на маленьком и большом iPhone Simulator;
- clean install, ATT после видимого onboarding, cold/relaunch и
  background/foreground;
- typed logs, scoped Debug Keychain cleanup, privacy manifest и отсутствие
  Debug-каталога в Release;
- token recovery возвращает полный backend balance авторизованного app account;
  transaction/checkout IDs используются только для exactly-once fulfillment;
- Usedesk contract хранит source token на backend, а account-scoped Keychain
  использует только как cache/pending sync без device ID identity;
- `stream_example_logs.sh` сразу показывает safe typed OSLog, корректно
  различает переименованные iPhone Simulator, объясняет выбор UDID и спокойно
  завершается по `Control-C`;
- debug-состояние AppFlow различает стабильный route и presentation
  `subscription-paywall` / `special-offer-resolver` / `special-offer`;
- README и developer guide согласованы для работы с агентом и вручную:
  `unresolved`/timeout разрешают обычный main без premium, а pending не
  превращается в успех;
- создание любого host app разделено на preflight, Integration Plan, skeleton,
  vertical slices, functional, visual и acceptance stages; старый монолитный
  build prompt удалён и запрещён documentation gate;
- универсальный копируемый Integration Plan отделяет platform-owned contracts
  от app-owned экранов, backend hooks и решений разработчика;
- универсальный app integration contract, Project Delivery checklist,
  functional-review checkpoint и QA handoff без привязки к номеру приложения.
- в Release доступность RU Billing определяется только verified-fresh
  `ru_pay = true`; SDK cache, Dashboard fallback и кеш `BroadMonetization` не
  авторизуют RU methods, собственного app-default `true` нет;
- ручное `ru_pay`-переопределение имеет три режима (`как в Adapty`, `включить`,
  `выключить`), хранится только в процессе, а template UI и store
  разблокируются только под `#if DEBUG`; default store fail-closed к
  Adapty и не обходит host configuration, контекст устройства, RU-каталог,
  backend authorization, backend kill switch или entitlement;
- причина доступности RU Billing выводится в Console типизированным safe-log без
  конфигурационного payload, идентификаторов пользователя и платёжных данных.

Настоящие purchase, restore и RU-платежи не запускались.

## Отчёты

- [`TemplateAcceptanceReport.md`](TemplateAcceptanceReport.md) — фактическая
  functional acceptance;
- [`MidpointAudit.md`](MidpointAudit.md) — аудит первой половины работ;
- [`SecurityPrivacyReview.md`](SecurityPrivacyReview.md) — security/privacy;
- [`SelfReview.md`](SelfReview.md) — финальный developer self-review;
- [`QAHandoff.md`](QAHandoff.md) — пакет передачи QA;
- [`ApplicationIntegrationContract.md`](ApplicationIntegrationContract.md) —
  универсальная граница platform и любого host app.
- [`AppCreationWorkflowAudit.md`](AppCreationWorkflowAudit.md) — midpoint и
  финальный аудит поэтапного создания приложений.

## Границы результата

- Обязательная матрица использует `Team = None`, iPhone Simulator и generic
  unsigned compile; платный аккаунт и Signing Team не требуются.
- Доступный компании ручной запуск на iPhone выполняется отдельно и не является
  blocker-ом platform/template.
- Каждый host app отдельно заполняет
  [`Documentation/ProjectDelivery.md`](../Documentation/ProjectDelivery.md) по
  своим Kaiten/design/backend/configuration данным.
- Независимый cold-read корневого README новым человеком остаётся полезным
  handoff, но не меняет технический platform `PASS`.

## Как получить свежий результат после своих изменений

С автоматическим исправлением:

```bash
./Scripts/agent_review_and_fix.sh
```

Только проверить:

```bash
bash Scripts/agent_gate.sh
```

Успешный terminal output заканчивается строкой
`BroadApps iOS Platform agent gate passed.`

<details>
<summary><strong>Технический source snapshot последнего PASS</strong></summary>

Формат локального отчёта описан в
[`AutomationReports/README.md`](AutomationReports/README.md). Команда
`agent_review_and_fix.sh` создаёт `AutomationReports/latest.md` локально; этот
runtime-файл намеренно не хранится в Git и поэтому не является ссылкой,
обязательной для clean clone.

</details>
