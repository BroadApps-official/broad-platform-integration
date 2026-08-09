# Исходники диаграмм README

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
Host App           #F59E0B
External           #64748B
```

GIF генерируются стандартными macOS `AppKit + ImageIO`, без внешних packages:

```bash
xcrun swift Documentation/Diagrams/generate_readme_gifs.swift
```

Результаты записываются в `Documentation/Assets/README/full-flow.gif` и `adaptive-paywall.gif`. Light/dark SVG рядом являются статическими fallback для документации и Reduce Motion просмотра.

Изменив диаграмму, обновите Mermaid source, обе SVG-темы и соответствующий GIF, затем проверьте внутренние ссылки и XML валидность SVG.
