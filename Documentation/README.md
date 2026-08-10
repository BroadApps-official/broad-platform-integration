# Документация BroadApps iOS Platform

Не нужно читать всё подряд. Выберите свою задачу:

| Что нужно сделать | Открыть |
|---|---|
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
| Перенести старое приложение | [Migration Guide](MigrationGuide.md) |
| Запустить агента-проверяющего | [Agent Automation](AgentAutomation.md) |
| Сверить готовность | [Traceability](Traceability.md) |

## Самый короткий маршрут для нового разработчика

1. [Getting Started](GettingStarted.md) — подключите нужные package products.
2. [Architecture](Architecture.md) — не смешивайте Domain, SDK и SwiftUI.
3. [Monetization](Monetization.md) — соберите один composition root.
4. [Account Recovery](AccountRecovery.md) — привяжите покупки к account/backend,
   а не к одной установке приложения.
5. Откройте профильный guide: RU billing, tokens, onboarding или paywall.
6. Запустите `./Scripts/agent_review_and_fix.sh` перед передачей изменений.

Все реальные идентификаторы приложения, Adapty placements, legal URL, API
paths и тексты остаются app-owned. Платформа даёт типы, порядок действий,
безопасные fallback и готовый UI.
