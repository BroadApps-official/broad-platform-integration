# Последняя подтверждённая проверка платформы

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
