# Последняя подтверждённая проверка платформы

## Результат

`PASS` — 9 сентября 2026 года полный `bash Scripts/agent_gate.sh` прошёл для
platform set `1.5.1`: `BroadCore 1.2.0`, `BroadExtensions 1.0.1`,
`BroadMonetization 1.5.3` и `BroadUIFlows 1.1.0`.

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
- RU Billing A/B доступен opt-in: общий session-bound tracker, подтверждённый
  assign → shown, один запрос при 30 одновременных callbacks, retry только при
  новом открытии, остановка при смене пользователя; HTTP проверен на fixtures;
- старые JSON и initializer действуют, включая точные типы ссылок на
  конструкторы; в public API относительно 1.4.1 нет удалённых объявлений;
- selector сохраняет исходный каталог, порядок/дубли и границу Special Offer,
  использует exact ID → isDefault → полный раздел;
- существующий template собран с candidate source до module tag и затем с
  точным публичным tag; подключение tracker в host app остаётся явным действием;
- обычный RU gate сохраняет verified-fresh правило; отдельно подключённый
  резерв при недоступном Adapty/продуктах использует свежий backend-каталог,
  если Storefront или регион iPhone RU/RUS; язык ничего не включает;
- отсутствие ответа отличается от полученного false/invalid/absent; ошибка
  продуктов не теряет полученный запрет. Optional placement обычной подписки сначала идёт в main,
  затем может сработать серверный резерв; ненастроенный main не маскируется;
- `tokens` и `special_offer` не заменяются основным paywall или обычными
  RU-подписками при сбое загрузки;
- успешный ответ продуктов `[]` включает серверный резерв при RU/RUS-регионе
  телефона или Storefront в той же попытке загрузки. Ошибка воспроизведена до
  исправления; после него прошли 256 сочетаний пустых ответов, регионов и
  плейсментов, включая запреты и исключения tokens/special_offer;
- резервные продукты сохраняют серверные ID/условия, порядок и дубли, не дают
  Apple checkout; свежий каталог повторно проверяет точную выбранную строку;
- JSON/cache не восстанавливает временное разрешение и A/B-назначение; отмена,
  одновременные запросы и отказ backend проверены отдельными contract probes;
- SwiftFormat, SwiftLint, architecture/privacy/docs checks, Package build,
  BroadAppTemplate Debug/Release Simulator, generic iOS compile и две live
  Adapty schemes прошли;
- Локальный `BroadMonetization 1.5.3` module gate и candidate template compile
  прошли до отправки tag. Версия `BroadUIFlows 1.1.0` не менялась.

## Отчёты

- [RU Billing A/B: API, подключение и проверки](../Documentation/RUBillingExperiments.md)
- Логи последнего полного запуска: `.build/GateLogs/01-validation.log`,
  `.build/GateLogs/04-build.log`, `.build/GateLogs/05-live-adapty.log`.

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
