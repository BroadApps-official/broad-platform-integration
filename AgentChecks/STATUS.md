# Последняя подтверждённая проверка платформы

## Результат

`PASS` — 9 сентября 2026 года полный `bash Scripts/agent_gate.sh` прошёл для
platform set `2.0.0`: `BroadCore 1.2.0`, `BroadExtensions 1.0.1`,
`BroadMonetization 2.0.0` и `BroadUIFlows 2.0.1`.

Scope — платформа, BroadAppTemplate и compile-only live Adapty schemes.
Настоящие purchase, restore и RU-платежи не запускались.

## Что подтверждено

- Все Remote Config ключи читаются из выбранного paywall `main`, включая
  `ru_pay`, `auto_revenue_view`, `special_offer`, `experiment_code`, `segment_code`.
  Конфигурации остальных placements не перекрывают main.
- Продукты, variation, SDK references и показ принадлежат своему placement;
  порядок и дубли сохраняются. Для tokens и offer нет подмены через main.
- Исполняемый контракт владельца проверяет противоречащие флаги, отсутствие
  и обновление main, ошибку целевого paywall, concurrency, cancellation
  и изоляцию конфигурации другой identity.
- Полученный запрет не теряется при ошибке продуктов. Gate и A/B-коды
  не восстанавливаются из прошлого ответа или постоянного кеша.
- Special Offer учитывает обновлённый main config при загрузке своих продуктов;
  более новый запрет отменяет прежнее разрешение, UI получает последние настройки.
- Fixture repository шаблона и Gallery следуют тому же контракту.
- В отдельном iPhone 16 Simulator (iOS 18.6) открыта Gallery Special Offer:
  продукты видны, countdown работает. В BroadAppTemplate при true закрытие
  обычного paywall открывает оффер; при false сразу открывается main.
- SwiftFormat, SwiftLint, architecture/privacy/docs checks, Swift Package,
  Debug/Release Simulator, unsigned iOS и обе live Adapty schemes прошли.
- До публикации module tags выполнены module gates и candidate template compile.
  Public API reports не изменились; major bump обусловлен сменой поведения.
- GitHub Module quality и Release прошли для обоих финальных модулей.

## Выпуски и ревизии

- [BroadMonetization 2.0.0](https://github.com/BroadApps-official/broad-monetization-ios/releases/tag/2.0.0):
  `389013f5b9b5f0c2b3ea7249a73a1a085b16994b`.
- [BroadUIFlows 2.0.1](https://github.com/BroadApps-official/broad-ui-flows-ios/releases/tag/2.0.1):
  `2bfce7cddefd500bcb7f034e9fba39d4ad2b7d7f`.
- Оба Package.resolved фиксируют эти exact versions и ревизии.

## Переход с 1.x

Перед обновлением перенесите общие ключи в используемые варианты/локали `main`.
Custom repositories передают main config с каждым payload и честный provenance.
Региональные проверки, server authority и отдельный RU-резерв сохраняются.
[Контракт Remote Config](../Documentation/RemoteConfig.md).

## Как повторить

```bash
bash Scripts/agent_gate.sh
```

Логи: `.build/GateLogs/01-validation.log`, `.build/GateLogs/04-build.log` и
`.build/GateLogs/05-live-adapty.log`. Успешный запуск заканчивается строкой
`BroadApps iOS Platform agent gate passed.`.
