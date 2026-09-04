# Последняя подтверждённая проверка платформы

## Результат

`PASS` — 4 сентября 2026 года полный `bash Scripts/agent_gate.sh` прошёл для
platform set `1.3.0`: `BroadCore 1.2.0`, `BroadExtensions 1.0.1`,
`BroadMonetization 1.3.1` и `BroadUIFlows 1.1.0`.

Scope результата — `BroadAppsIOSPlatform` и `BroadAppTemplate`. Настоящие
purchase, restore и RU-платежи не запускались.

## Что подтверждено

- strict boolean `special_offer = true` читается из Remote Config обычного
  paywall; отсутствующее, ложное или не-bool значение fail-closed;
- после gate загружается отдельный placement `special_offer`, все продукты
  сохраняются 1:1 в provider order без filter/sort/dedup;
- первый подходящий close запускает persisted-окно 24 часа, затем ровно от его
  конца идёт cooldown 24 часа; countdown заканчивается на нуле и закрывает UI;
- flag off, confirmed purchase и restore сбрасывают cycle; active entitlement
  блокирует offer до загрузки второго paywall;
- RU Special Offer выбирает только backend row с `isSpecialOffer`, исключает её
  из обычного paywall и не подставляет обычный тариф;
- A/B-тесты RU Billing не выдаются за готовую функцию и не имеют инструкции по
  настройке;
- `ru_pay` по-прежнему требует verified-fresh payload и RU Storefront либо
  RU-регион iPhone; язык ничего не включает;
- SwiftFormat, SwiftLint, architecture/privacy/docs checks, Package build,
  BroadAppTemplate Debug/Release Simulator, generic iOS compile и две live
  Adapty schemes прошли;
- Module quality и Release workflows для `BroadMonetization 1.3.1` и
  `BroadUIFlows 1.1.0` завершились успешно, GitHub Releases опубликованы.

## Отчёты

- [`TemplateAcceptanceReport.md`](TemplateAcceptanceReport.md)
- [`SecurityPrivacyReview.md`](SecurityPrivacyReview.md)
- [`QAHandoff.md`](QAHandoff.md)
- [`ApplicationIntegrationContract.md`](ApplicationIntegrationContract.md)

## Границы результата

- Проверка использует `Team = None`, iPhone Simulator и generic unsigned iOS.
- Реальные StoreKit/RU операции и внешние кабинеты не изменяются.
- Каждый host app отдельно подставляет public key, placements, product IDs,
  backend и legal configuration текущего проекта.

## Как повторить

```bash
bash Scripts/agent_gate.sh
```

Успешный output заканчивается строкой
`BroadApps iOS Platform agent gate passed.`
