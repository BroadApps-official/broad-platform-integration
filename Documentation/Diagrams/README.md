# Визуальные материалы README

## Экраны полного RU Billing flow

`Documentation/Assets/README/References` хранит уменьшенные копии семи реальных
iPhone-экранов: paywall, выбор RU-оплаты, заполненные согласия,
сообщение об обязательном согласии, отдельный ввод email и два варианта внешней
оплаты. Вместе они показывают последовательность и обязательные элементы
RU-покупки; визуальный стиль конкретного приложения может отличаться.

| Файл | Что показывает |
|---|---|
| `5115-paywall-dark.png` | продуктовый paywall |
| `5115-payment-methods-dark.png` | выбор способа оплаты |
| `5115-payment-ready-dark.png` | заполненные обязательные согласия |
| `5115-consent-alert-dark.png` | сообщение о пропущенном согласии |
| `5115-receipt-email-dark.png` | отдельный ввод email для чека |
| `5115-cloudpayments-light.png` | внешняя форма банковской карты |
| `5115-hosted-checkout-light.png` | компактная внешняя форма оплаты |

При обновлении этих изображений не добавляйте экраны с платёжными реквизитами,
персональными данными или внутренними идентификаторами. Для README достаточно
PNG `645×1398` — половины исходного Retina-размера.

## Реальные экраны example

`Documentation/Assets/README/Screenshots` содержит настоящие снимки
`BroadAppTemplate`, собранного и запущенного на iPhone 17 Pro Simulator:

| Файл | Fixture |
|---|---|
| `onboarding-ru-v2.png` | первый русский onboarding-слайд, `-tracking-disabled` |
| `paywall-showcase-ru-v2.png` | русский адаптивный paywall с одинаковыми карточками |
| `paywall-one-ru-v2.png` | один продукт + автоматический выбор |
| `paywall-two-ru-v2.png` | два продукта в порядке провайдера |
| `paywall-many-ru-v2.png` | paywall с 12 продуктами провайдера |
| `payment-methods-light.png` | UI-only выбор App Store / СБП / карты |
| `ru-payment-methods-v3.png` | Apple/СБП/карта, согласия без отдельных legal-ссылок, кнопка всегда видна |
| `ru-payment-apple-v2.png` | Apple без RU-полей согласия и чека |
| `ru-payment-receipt-v2.png` | отдельный шаг email для кассового чека |
| `ru-subscription-active-v2.png` | управление активной RU-подпиской |
| `ru-subscription-cancelled-v2.png` | доступ после отключения автопродления |
| `paywall-empty-ru-v2.png` | безопасное состояние без тарифов |
| `paywall-error-ru-v2.png` | безопасная ошибка с повтором |
| `main-ru-v2.png` | основной экран после завершённого сценария |

Скриншоты снимаются с фиксированным status bar `9:41`, без системных prompt и
без настоящего платежа. Перед обновлением изображения нужно заново собрать
example, запустить соответствующий fixture и убедиться, что на снимке нет
локальных уведомлений или отладочных окон. PNG хранится в размере `603×1311`:
этого достаточно для Retina-превью README без лишнего веса репозитория.

## Схемы и анимации

| Файл | Что описывает |
|---|---|
| `module-dependencies.mmd` | границы host/Core/Monetization/UIFlows/external |
| `first-run-flow.mmd` | полный first-run и entitlement decision |
| `paywall-fallback.mmd` | requested/cache/main fallback |
| `adaptive-products.mmd` | products 1:1 до UI/purchase |
| `entitlement-authority.mmd` | aggregation Apple/backend/RU |
| `generate_readme_gifs.swift` | воспроизводит две короткие GIF-анимации |
| `Scripts/generate_federation_diagrams.rb` | воспроизводит light/dark SVG новой repository-схемы |

Отдельные SVG, которые объясняют путь разработчика и не требуют Mermaid:

| Light / dark пара | Что объясняет |
|---|---|
| `full-flow-*.svg` | как обычный main отделён от premium: route выбирает flow policy, premium открывает только active entitlement |
| `project-inputs-*.svg` | как метка `no-code` в карточке Kaiten определяет источник интерфейса и как временные данные заменяются перед выпуском |
| `composition-root-*.svg` | как собрать зависимости в одном месте и какие ограничители безопасности должны быть единственными в приложении |
| `no-code-agent-workflow-*.svg` | что делает разработчик и что делает Codex/Claude при создании no-code-приложения |
| `no-code-manual-workflow-*.svg` | полный ручной no-code-маршрут от Kaiten и согласованного дизайна до проверенных сборок |
| `agent-click-path-*.svg` | на какие элементы Finder и Codex/Claude нажать, чтобы открыть правильную папку, передать материалы и запустить разработку |
| `app-delivery-iterations-*.svg` | почему функциональный PASS и визуальная сверка являются разными итерациями, а QA начинается только после self-review |
| `platform-module-selection-*.svg` | host app выбирает любой нужный модуль без обязательного umbrella |
| `federated-repositories-*.svg` | ownership кода, integration и public docs между repositories |
| `repository-migration-*.svg` | порядок безопасного выноса модулей из исходного repository |
| `module-release-flow-*.svg` | standalone gate, SemVer release и обновление compatibility catalog |
| `cross-repo-change-*.svg` | порядок owner → consumers → integration → docs |
| `documentation-pipeline-*.svg` | Markdown/DocC как source и public site с search/Edit this page |

Цвета фиксированы общей легендой:

```text
BroadCore          #3B82F6
BroadMonetization  #10B981
BroadUIFlows       #EC4899
BroadExtensions    #8B5CF6
Host App           #F59E0B
External           #64748B
```

GIF генерируются стандартными macOS `AppKit + ImageIO`, без внешних packages:

```bash
xcrun swift Documentation/Diagrams/generate_readme_gifs.swift
```

Результаты записываются в `Documentation/Assets/README/full-flow.gif` и
`adaptive-paywall.gif`. Для first-run flow дополнительно хранится пара
`full-flow-light.svg` / `full-flow-dark.svg`: README показывает статическую
схему сразу, а GIF открывается по желанию. `adaptive-paywall.gif` остаётся без
отдельной SVG-пары. Точное поведение и ограничения также описаны текстом.

Изменив анимацию, обновите Swift-генератор и соответствующий GIF, затем
проверьте внутренние ссылки. Для остальных схем обновляйте Mermaid source или
обе SVG-темы — в зависимости от формата конкретной схемы.
Шесть federation-пар не редактируйте вручную: меняйте
`Scripts/generate_federation_diagrams.rb` и перегенерируйте обе темы.
