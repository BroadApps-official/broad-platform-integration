# Документация BroadApps iOS Platform

Не нужно читать всё подряд. Выберите свою задачу:

| Что нужно сделать | Открыть |
|---|---|
| Сверить архитектуру, use cases и UI перед передачей | [Памятка разработчика](../README.dev.md) |
| Впервые подключить package | [Getting Started](GettingStarted.md) |
| Создать новое приложение по этапам | [App Creation Workflow](AppCreationWorkflow.md) · [готовые prompts](AgentPromptPack.md) |
| Зафиксировать экраны, API и ownership до кода | [Шаблон Integration Plan](Templates/AppIntegrationPlan.md) · [нейтральный пример](Examples/NeutralAppIntegrationPlan.md) |
| Пройти полную ручную приёмку BroadAppTemplate | [Приёмка template](TemplateAcceptance.md) |
| Посмотреть фактический прогон и QA handoff template | [Acceptance report](../AgentChecks/TemplateAcceptanceReport.md) · [Workflow audit](../AgentChecks/AppCreationWorkflowAudit.md) · [Self-review](../AgentChecks/SelfReview.md) · [QA handoff](../AgentChecks/QAHandoff.md) |
| Подготовить конкретное приложение к self-review и QA | [Project Delivery](ProjectDelivery.md) |
| Правильно запустить SDK и кешировать контент | [Запуск SDK и кеш](StartupAndCaching.md) |
| Добавить Debug-очистку Keychain и мгновенный loader кнопки | [Debug и async-действия](DebugToolsAndAsyncActions.md) |
| Понять папки и зависимости | [Architecture](Architecture.md) |
| Настроить Adapty, StoreKit и общий flow | [Monetization](Monetization.md) |
| Выбрать subscriptions-only или subscriptions + tokens | [Purchase Managers](PurchaseManagers.md) |
| Подключить отдельный consumable token paywall | [Token Paywall](TokenPaywall.md) |
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
| Проверить Kaiten, дизайн, reference и backend до Integration Plan | [Agent Preflight](AgentPreflight.md) |
| Посмотреть, что уже умеет платформа | [Карта возможностей](Traceability.md) |

## Самый короткий маршрут для нового разработчика

| Ваш путь | Читать сначала | Когда считать завершённым |
|---|---|---|
| Codex/Claude создаёт новое приложение | [Agent Preflight](AgentPreflight.md), [Workflow](AppCreationWorkflow.md) и [Prompt Pack](AgentPromptPack.md) | Подтверждены все review-точки, затем functional + visual audit и self-review разработчика |
| Разработчик собирает приложение вручную | [Вариант B](../README.md#manual-setup), [Workflow](AppCreationWorkflow.md) и [шаблон плана](Templates/AppIntegrationPlan.md) | План проверен; Debug/Release, безопасные flow и screenshot-to-source сверка прошли |
| Нужно принять интерактивный пример | [Приёмка template](TemplateAcceptance.md) | Каждая строка матрицы проверена на маленьком и большом iPhone |
| Нужно передать конкретное приложение QA | [Project Delivery](ProjectDelivery.md) | Собраны functional, visual, Simulator, configuration и security evidence; self-review завершён |
| Изменён код самой платформы | [`AGENTS.md`](../AGENTS.md) и [Agent Automation](AgentAutomation.md) | Последняя строка `bash Scripts/agent_gate.sh` сообщает PASS |

Не смешивайте эти пути: platform gate не заменяет проверку конкретного app, а
сборка app не заменяет gate после изменения `BroadAppsIOSPlatform`.

1. [Памятка разработчика](../README.dev.md) — поймите, куда класть код и что проверять.
2. [Getting Started](GettingStarted.md) — подключите нужные package products.
3. [Запуск SDK и кеш](StartupAndCaching.md) — разделите critical, background и lazy сервисы.
4. [Debug и async-действия](DebugToolsAndAsyncActions.md) — обеспечьте мгновенный отклик backend-кнопок и удобную Debug-разработку.
5. [Architecture](Architecture.md) — не смешивайте Domain, SDK и SwiftUI.
6. [Monetization](Monetization.md) — соберите один composition root.
7. [Account Recovery](AccountRecovery.md) — привяжите покупки к account/backend,
   а не к одной установке приложения.
8. Откройте профильный guide: RU billing, tokens, onboarding, paywall,
   Support Email или Usedesk.
9. Если меняли код платформы, запустите обязательную проверку по
   [инструкции Agent Automation](AgentAutomation.md).

Все реальные идентификаторы приложения, Adapty placements, legal URL, API
paths и тексты остаются app-owned. Платформа даёт типы, порядок действий,
безопасные fallback и готовый UI.
