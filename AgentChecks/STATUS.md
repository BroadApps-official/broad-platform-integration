# Последняя подтверждённая проверка платформы

## Keychain account identity — набор 4.1.0, 11 сентября 2026

Набор: **BroadCore 2.1.0, BroadExtensions 1.0.1, BroadMonetization 4.0.0,
BroadUIFlows 4.0.0**. Команда приёмки: `bash Scripts/agent_gate.sh`;
лог — `.build/keychain-4.1-final-gate.log`.

- BroadCore #6 объединён после исправления конфликтов при генерации ID.
  Окончательная iCloud identity выбирается до публикации локальной записи.
  Неудачное чтение конфликта и локальная запись оставляют восстановление
  повторяемым; два экземпляра store не получают промежуточный новый ID.
- Исполняемые contract probes проверяют эти случаи с подставным хранилищем.
  Полный module gate проходит девять этапов, включая public API и DocC.
  [Module quality исправления](https://github.com/BroadApps-official/broad-core-ios/actions/runs/34622171214).
- До тега собран кандидат с локальным Core: Debug/Release Simulator,
  обе live Adapty configurations и Release generic iOS без подписи.
- В live-примере один store обслуживает persistent Adapty identity и проверки
  перед активацией/загрузкой paywall. Keychain failure не превращается в nil
  identity для создания нового анонимного SDK-профиля.
- Синхронизация iCloud в шаблоне выключена до согласования backend identity.
  Серверная авторизация, баланс, расходы и бонусы остаются app-owned контрактом;
  token fixture в памяти не выдаётся за серверное хранение.
- Настоящие Keychain/iCloud, покупка, restore и backend-операции не выполнялись.
  Успешные сборки не подтверждают фактический перенос между устройствами.

Core 2.1.0: `78c6c091d29d057c842092d2d1f0ccc557bef14d`.
[Подключение и границы восстановления](../Documentation/AccountRecovery.md).

## Token recovery и host logging — набор 4.0.0, 11 сентября 2026

Набор: **BroadCore 2.0.0, BroadExtensions 1.0.1, BroadMonetization 4.0.0,
BroadUIFlows 4.0.0**. Команда приёмки: `bash Scripts/agent_gate.sh`;
лог полного прогона — `.build/release-4-final-gate.log`.

- Полные module gates проверяют типизированный host logging, public API,
  DocC и standalone Debug/Release iPhone examples.
- Token fulfillment probe подтверждает recovery после `.failed` с обоими
  retry hints, `.pending` и `.unavailable`: evidence и attempt ID сохраняются,
  повтор не вызывает вторую покупку. Проверены `.rejected`, `.alreadyCredited`
  и ошибка очистки persistent store.
- Core compile-negative probe отклоняет runtime String для event code,
  имени поля и текстового значения; разрешены StaticString, Bool и Int.
- До тегов проверена совместная candidate-сборка: Debug/Release Simulator
  и Release generic iOS без подписи. Для публичных тегов выполняются полный
  integration gate и отдельное чистое разрешение пакетов без Git credentials.
- UIFlows public API report совпадает; изменены только диапазоны зависимостей,
  Gallery configuration и документация. Extensions 1.0.1 переиспользуется.
- Настоящие purchase, restore и production backend операции не выполнялись.

| Модуль | Ревизия тега | GitHub Release workflow |
|---|---|---|
| Core 2.0.0 | `97c274e7f78654fca7c6be489af315f8e3941c4c` | [Run 34592879610](https://github.com/BroadApps-official/broad-core-ios/actions/runs/34592879610) |
| Monetization 4.0.0 | `bad749f7f0cb772021793cd121ec4c6a50ba14ac` | [Run 34592900333](https://github.com/BroadApps-official/broad-monetization-ios/actions/runs/34592900333) |
| UIFlows 4.0.0 | `030dbfd7b22f4b919c5e25b204a80de999d42b57` | [Run 34592915880](https://github.com/BroadApps-official/broad-ui-flows-ios/actions/runs/34592915880) |

Инструкция команде: [обновление на набор 4.0.0](../Documentation/UpdatingTo4.md).
Состояние последнего опубликованного набора — в
[Compatibility/current.yml](../Compatibility/current.yml).

Ниже — исторические результаты предыдущих наборов.

## Account-policy RU checkout — набор 3.0.0

Проверяются BroadCore 1.2.0, BroadExtensions 1.0.1, BroadMonetization 3.0.0
и BroadUIFlows 3.0.0. Команда полной приёмки: `bash Scripts/agent_gate.sh`,
лог текущего прогона: `.build/account-final-gate.log`.

- Локальный `module_gate.sh` обоих изменённых модулей — PASS, включая
  public API reports, DocC, SwiftFormat/SwiftLint и unsigned iPhone examples.
- До тегов собран integration candidate с исходниками модулей; Debug/Release
  Simulator и Release generic iOS прошли. После тегов оба lockfile разрешены
  в опубликованные 3.0.0, `Scripts/build.sh` прошёл всю матрицу повторно.
- Account-policy probe проверяет тариф/период, исходный баланс, 8 попыток,
  ошибку вместо stale success, смену сессии, сохранение context, pending
  и объединение foreground/dismiss. HTTP probe проверяет GET policy/effective,
  отсутствие cache, ошибки авторизации/сервера и старый snake_case wire.
- Новый режим подтверждает состояние аккаунта, не конкретную транзакцию.
  Неопределённый результат остаётся pending; Retry не создаёт новый checkout.
- UIFlows согласует диапазон зависимости 3.x; собственные UI API не менялись.
  Реальные покупки, restore и обращения к production backend не выполнялись.

Ревизии модулей: Monetization `c55174b460853f88f8d6340e702d6eead0d49dc1`,
UIFlows `b5718a6a348a10a7ed50f352361eda6f585e2f70`.
[Monetization Module quality](https://github.com/BroadApps-official/broad-monetization-ios/actions/runs/34472909093),
[UIFlows Module quality](https://github.com/BroadApps-official/broad-ui-flows-ios/actions/runs/34473499612).

Ниже — исторические результаты набора 2.0.1; они не заменяют приёмку 3.0.0.

## Единый reviewer — 10 сентября 2026

- Добавлены явные режимы platform/app, аудит по умолчанию и --fix.
- Проверены подготовка пяти repositories и app build matrix без запуска
  вложенного агента. Временный CLI smoke с подставными Codex/Xcode процессами
  подтвердил PASS/ISSUES/BLOCKED, открытое замечание при зелёной сборке,
  неполный ответ, аварийный выход, изменение исходников и повторные gates с --fix.
- `bash Scripts/agent_gate.sh` — PASS; лог `.build/reviewer-final-gate.log`.
- Semantic аудит приложения выполняется по выбранным исходникам; успешный
  CLI smoke не выдаётся за настоящий автоматический аудит или оплату.
- Исторический отчёт 1.3.0 явно помечен; новые отчёты остаются в .build цели.
- Публичные API и runtime версии пакетов в этой правке не менялись.

## Результат

`PASS` — 10 сентября 2026 года полный `bash Scripts/agent_gate.sh` прошёл для
platform set `2.0.1`: `BroadCore 1.2.0`, `BroadExtensions 1.0.1`,
`BroadMonetization 2.0.1` и `BroadUIFlows 2.0.1`.

Scope — платформа, BroadAppTemplate и compile-only live Adapty schemes.
Настоящие purchase, restore и RU-платежи не запускались.

## Что исправлено

- Remote Config читается из выбранного paywall текущего placement: settings
  использует настройки settings. Main заполняет только отсутствующие ключи.
- Явные false, null и malformed значения placement не заменяются main.
  Aliases разрешаются одной группой; experiment/segment не смешиваются
  между A/B-вариантами.
- Недоступный main не лишает текущий paywall его конфигурации. Полученный
  запрет сохраняется при ошибке продуктов; cache не восстанавливает gate.
- Настроенный token/tokens пробуется первым, альтернативное написание —
  при отсутствии paywall. Оба logical ID исключены из подписочного fallback.
- Продукты, порядок и дубли, variation и SDK references сохраняются у своего
  paywall. Токены и Special Offer не подменяются продуктами main.
- Fixture repository шаблона использует текущий placement с main fallback.

## Что проверено

- Полный module gate BroadMonetization и GitHub Module quality прошли
  для ревизии `da6f253b037b49b3f6eed9949a09cf5206f2b1a0`.
- Исполняемые contract probes проверяют приоритет полей, false/null/invalid,
  отсутствие main, обновление ответов, concurrency, cancellation,
  token/tokens, успешный первый ответ и сохранение custom ID.
- Public API report не изменился. Выпуск 2.0.1 исправляет ошибочное поведение
  2.0.0 без изменения публичных сигнатур.
- Оба Package.resolved автоматически разрешены в точную версию 2.0.1
  и проверенную ревизию модуля.
- SwiftFormat, SwiftLint, architecture/privacy/docs checks, Swift Package,
  Debug/Release Simulator, unsigned iOS и обе live Adapty schemes прошли.
- Визуальные сценарии не перезапускались: изменение касается загрузки данных.

## Выпуски

- [BroadMonetization 2.0.1](https://github.com/BroadApps-official/broad-monetization-ios/releases/tag/2.0.1).
- [GitHub Module quality](https://github.com/BroadApps-official/broad-monetization-ios/actions/runs/34463677184).
- [BroadUIFlows 2.0.1](https://github.com/BroadApps-official/broad-ui-flows-ios/releases/tag/2.0.1).

## Обновление

Проверьте собственные ключи используемых paywall: они имеют приоритет.
Main используется как резерв. Custom repositories соблюдают тот же порядок.
Для Special Offer после settings задайте `gatePlacementID: .settings`.
Региональные проверки, server authority и отдельный RU-резерв сохраняются.
[Контракт Remote Config](../Documentation/RemoteConfig.md).

## Как повторить

```bash
bash Scripts/agent_gate.sh
```

Логи: `.build/GateLogs/01-validation.log`, `.build/GateLogs/04-build.log` и
`.build/GateLogs/05-live-adapty.log`. Успешный запуск заканчивается строкой
`BroadApps iOS Platform agent gate passed.`.
