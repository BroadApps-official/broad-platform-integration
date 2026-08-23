# Последняя подтверждённая проверка платформы

## Результат

`PASS` — полный local gate прошёл 23 августа 2026 года после повторного аудита
замечаний разработчика, исправления Special Offer catalog flow, общей аналитики
и обновления developer instructions.

Scope результата — только `BroadAppsIOSPlatform` и `BroadAppTemplate`. Он не
переносится автоматически ни на одно приложение, созданное поверх платформы.

## Что подтверждено

- правила, архитектура, privacy, documentation links и README assets;
- SwiftFormat и SwiftLint без нарушений;
- Swift Package и iPhone example в Debug/Release Simulator;
- Release generic iOS device compile без подписи;
- две live Adapty configurations только компиляцией, без финансовых действий;
- полная fixture-матрица AppFlow, entitlement, special offer и token flow;
- карточка Special Offer проходит subscription paywall → resolver → offer,
  получает новую presentation authorization и пишет события обоих paywall в
  общий process recorder;
- Debug refresh аналитики показывает spinner, timestamp и явное empty state;
- девять карточек каталога на маленьком и большом iPhone Simulator;
- clean install, ATT после видимого onboarding, cold/relaunch и
  background/foreground;
- typed logs, scoped Debug Keychain cleanup, privacy manifest и отсутствие
  Debug-каталога в Release;
- универсальный app integration contract, Project Delivery checklist,
  functional-review checkpoint и QA handoff без привязки к номеру приложения.

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

`0b12527413b1059b840f718e5341c1ea721deb15d5437cbfe48bb385ce4e7d00`

</details>
