# Что уже умеет BroadApps iOS Platform

Найдите нужную задачу и откройте инструкцию рядом.

## Возможности платформы

| Задача приложения | Что использовать | Инструкция |
|---|---|---|
| Запуск SDK, cache, offline, timeout и retry | `BroadCore` + доменные cache-адаптеры | [Запуск SDK и кеш](StartupAndCaching.md), [Bootstrap](Bootstrap.md), [Caching & Offline](CachingAndOffline.md) |
| Onboarding и правильный момент ATT | `BroadUIFlows` + tracking adapter из `BroadCore` | [Onboarding & ATT](OnboardingAndATT.md) |
| Paywall для любого количества продуктов | `BroadUIFlows` + `BroadMonetization` | [Paywall UI](PaywallUI.md) |
| Adapty placements, fallback на `main` и experiments | `BroadMonetization` | [Monetization](Monetization.md), [Experiments](Experiments.md) |
| Подписка без tokens | `SubscriptionPurchaseManager` | [Purchase Managers](PurchaseManagers.md) |
| Подписка и покупка tokens | Независимые subscription и token managers | [Purchase Managers](PurchaseManagers.md) |
| Проверка premium после purchase/restore | Entitlement engine | [Entitlements](Entitlements.md) |
| СБП, карта, чек, согласия и управление RU-подпиской | RU Billing adapters и UI | [RU Billing](RUBilling.md) |
| Опциональный special offer | Special offer contracts | [Special Offer](SpecialOffer.md) |
| Provider Remote Config против platform cache | Provenance capability + обязательная contract matrix | [Remote Config](RemoteConfig.md), [ADR-0005](ADR/0005-provider-managed-remote-feature-gates.md) |
| Общая аналитика показов и покупок | Monetization analytics pipeline | [Analytics](Analytics.md) |
| Восстановление после переустановки | Account recovery + server-authoritative ledger | [Account Recovery](AccountRecovery.md) |
| Безопасное поведение при обрыве сети | Typed network failures и pending reconciliation | [Network Interruptions](NetworkInterruptions.md) |
| Мгновенный spinner backend-кнопки и Debug-очистка Keychain | `BroadActionButton` + `DebugKeychainCleaner` | [Debug и async-действия](DebugToolsAndAsyncActions.md) |
| Hex Color, fonts, keyboard и swipe-back | `BroadExtensions` | [BroadExtensions](Extensions.md) |
| Онлайн-чат поддержки из Settings | App-owned Usedesk CocoaPods adapter + backend chat token | [Usedesk](Usedesk.md) |
| Письмо в поддержку, распознаваемое ботом | Единый app/device/ID/diagnostics body + `(ukassa)` variant | [Support Email](SupportEmail.md) |

## Что всё равно задаёт конкретное приложение

- тип проекта по метке карточки Kaiten: `no-code` означает отсутствие Figma,
  без этой метки проект работает по Figma;
- тексты, изображения, цвета, шрифты и экраны бренда;
- bundle ID, ссылки и public Adapty configuration из документа Kaiten;
- product IDs, placements и feature flags;
- app account и backend-контракты для tokens и RU Billing;
- необходимость Usedesk, его `Company ID`/`Channel ID` и backend-хранение user
  chat token;
- основной экран и бизнес-функции продукта.

Если финальные public client values ещё не готовы, используется fixture либо
явно согласованные public SDK/placement/product values похожего live-приложения
только для load/show. Signing team, bundle, credentials, keys/certificates,
backend auth и account/user данные из reference не копируются. Перед выпуском
временные public values заменяются данными текущего проекта.

## Как проверить изменение платформы

С Codex и автоматическим исправлением:

```bash
./Scripts/agent_review_and_fix.sh
```

Без автоматического исправления:

```bash
bash Scripts/agent_gate.sh
```

Готовый результат заканчивается строкой:

```text
BroadApps iOS Platform agent gate passed.
```

[Подробная инструкция по проверяющему агенту →](AgentAutomation.md)

## Что проверяется отдельно в приложении

Platform gate не собирает чужой app target. В конкретном приложении разработчик
отдельно проверяет Debug/Release build, выбранный дизайн, ссылки, backend,
fixture-сценарии и свои production-конфигурации.
