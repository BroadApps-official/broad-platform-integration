# Документация BroadApps iOS Platform

Не нужно читать всё подряд. Выберите свою задачу:

| Что нужно сделать | Открыть |
|---|---|
| Сверить архитектуру, use cases и UI перед передачей | [Памятка разработчика](../README.dev.md) |
| Впервые подключить package | [Getting Started](GettingStarted.md) |
| Понять папки и зависимости | [Architecture](Architecture.md) |
| Настроить Adapty, StoreKit и общий flow | [Monetization](Monetization.md) |
| Выбрать subscriptions-only или subscriptions + tokens | [Purchase Managers](PurchaseManagers.md) |
| Не потерять покупки после переустановки | [Account Recovery](AccountRecovery.md) |
| Обработать внезапное отключение сети | [Network Interruptions](NetworkInterruptions.md) |
| Подключить полный СБП/карта flow | [RU Billing](RUBilling.md) |
| Настроить adaptive paywall | [Paywall UI](PaywallUI.md) |
| Настроить onboarding, ATT и Rate Us | [Onboarding & ATT](OnboardingAndATT.md) |
| Подключить общие extensions | [BroadExtensions](Extensions.md) |
| Настроить placements и remote config | [Remote Config](RemoteConfig.md) |
| Проверить эксперименты | [Experiments](Experiments.md) |
| Подключить аналитику | [Analytics](Analytics.md) |
| Добавить единую форму письма в поддержку | [Support Email](SupportEmail.md) |
| Добавить онлайн-чат Usedesk в Settings | [Usedesk](Usedesk.md) |
| Перенести старое приложение | [Migration Guide](MigrationGuide.md) |
| Запустить агента-проверяющего | [Agent Automation](AgentAutomation.md) |
| Посмотреть, что уже умеет платформа | [Карта возможностей](Traceability.md) |

## Самый короткий маршрут для нового разработчика

1. [Памятка разработчика](../README.dev.md) — поймите, куда класть код и что проверять.
2. [Getting Started](GettingStarted.md) — подключите нужные package products.
3. [Architecture](Architecture.md) — не смешивайте Domain, SDK и SwiftUI.
4. [Monetization](Monetization.md) — соберите один composition root.
5. [Account Recovery](AccountRecovery.md) — привяжите покупки к account/backend,
   а не к одной установке приложения.
6. Откройте профильный guide: RU billing, tokens, onboarding, paywall,
   Support Email или Usedesk.
7. Если меняли код платформы, запустите `./Scripts/agent_review_and_fix.sh`.

Все реальные идентификаторы приложения, Adapty placements, legal URL, API
paths и тексты остаются app-owned. Платформа даёт типы, порядок действий,
безопасные fallback и готовый UI.
