# Визуальные материалы README

## Реальные экраны example

`Documentation/Assets/README/Screenshots` содержит настоящие снимки
`BroadAppTemplate`, собранного и запущенного на iPhone 17 Pro Simulator:

| Файл | Fixture |
|---|---|
| `onboarding-dark.png` | первый onboarding-слайд, `-tracking-disabled` |
| `paywall-light.png` | обычный adaptive paywall |
| `paywall-one-light.png` | один продукт + automatic selection |
| `paywall-two-dark.png` | два продукта в provider order |
| `paywall-many-dark.png` | paywall с 12 provider products |
| `payment-methods-light.png` | UI-only выбор App Store / СБП / карты |
| `ru-payment-sbp-light.png` | СБП + две обязательные галочки + чек/email |
| `ru-payment-apple-light.png` | Apple selected без RU consent/receipt полей |
| `ru-subscription-active-light.png` | RU subscription management до отмены |
| `ru-subscription-cancelled-light.png` | paid-through доступ после отмены |
| `paywall-empty-dark.png` | безопасный empty state |
| `paywall-error-dark.png` | безопасный error + retry state |
| `main-dark.png` | main fixture после завершённого flow |

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

Результаты записываются в `Documentation/Assets/README/full-flow.gif` и `adaptive-paywall.gif`. Light/dark SVG рядом являются статическими fallback для документации и Reduce Motion просмотра.

Изменив диаграмму, обновите Mermaid source, обе SVG-темы и соответствующий GIF, затем проверьте внутренние ссылки и XML валидность SVG.
