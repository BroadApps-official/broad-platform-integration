# Проверяющие агенты BroadApps iOS Platform

Эти семь handoff-заданий запускаются отдельно. Каждый reviewer только читает
код, запускает безопасные локальные проверки и формирует snapshot-bound отчёт.
Они не изменяют файлы, не переформатируют код и не исправляют findings.

## Автоматический review-and-fix

Для обычной ежедневной работы есть отдельный агент, которому разрешены
минимальные platform-owned исправления:

```bash
./Scripts/agent_review_and_fix.sh
```

Он использует [`AUTOMATION_PROMPT.md`](AUTOMATION_PROMPT.md), повторяет gate до
PASS и пишет понятный runtime-отчёт. По решению руководства Codex получает
полный доступ к Mac, чтобы сам запускать Xcode/CoreSimulator gate. Scope при
этом остаётся только `BroadAppsIOSPlatform`; wrapper после ответа независимо
повторяет тот же gate. Это не заменяет семь независимых handoff reports:
auto-fix и финальная приёмка намеренно разделены.

[Как пользоваться автоматикой →](../Documentation/AgentAutomation.md)

## Порядок проверки

1. [`architecture.md`](architecture.md) — модули, Clean Architecture, MVVM, SOLID и DI.
2. [`ui.md`](ui.md) — общие UI-состояния, адаптивность и accessibility.
3. [`onboarding-att-rateus.md`](onboarding-att-rateus.md) — правила onboarding, ATT и Rate Us.
4. [`paywall.md`](paywall.md) — любое число продуктов, adaptive UI и отсутствие press-effect.
5. [`monetization.md`](monetization.md) — placements, fallback, purchase, restore и entitlement.
6. [`ru-billing.md`](ru-billing.md) — storefront RUS, checkout, polling, cancel и unresolved.
7. [`security.md`](security.md) — секреты, PII, сеть, кеш и безопасные ошибки.

Каждый отчёт оформляется по [`REPORT_TEMPLATE.md`](REPORT_TEMPLATE.md). Отсутствие findings нужно указать явно; молчание не считается `PASS`.

Текущая сводка сохранённых отчётов лежит в [STATUS.md](STATUS.md). Это
отдельный mutable dashboard; reviewer routing и правила этого `INDEX.md`
остаются частью source snapshot.

## Локальный gate

```bash
bash Scripts/release_gate.sh
```

Gate выполняет `validate`, строгий lint и сборку Swift Package с example-приложением. Успешный gate не заменяет семь предметных отчётов.

Handoff gate дополнительно проверяет exact source digest, acceptance UUID,
fresh timestamps и `PLATFORM_LOCAL` scope во всех отчётах. StoreKit sandbox,
device accessibility matrix, `.ipa` и host attestations не используются.
Инструкция: [Platform Handoff](../Documentation/PlatformHandoff.md).
