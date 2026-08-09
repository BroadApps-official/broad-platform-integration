# Приёмка и передача BroadApps iOS Platform

Платформа передаётся для iPhone-приложений (`TARGETED_DEVICE_FAMILY = 1`).
iPad, Mac, Mac Catalyst и visionOS не входят в scope версии 1.0.

Этот документ фиксирует реальный scope платформы. `BroadAppsIOSPlatform`
готовится как локальный Swift Package и передаётся разработчикам приложений.
Встраивание в конкретные production-приложения выполняется ими позднее и не
блокирует готовность самого package.

## Ограничения компании

| Пункт | Решение |
|---|---|
| Внедрение в реальные приложения | Отложено до работы app-команд |
| StoreKit sandbox purchase/restore | Недоступно по правилам компании и не входит в acceptance |
| VoiceOver/Dynamic Type на физических устройствах | Не выполняется и не является blocker-ом |
| Distribution-signed `.ipa` | Не требуется для Swift Package handoff |
| Host attestations | Не используются |
| Unit/UI test targets | Не создаются по принятой policy |

Платформа продолжает иметь semantic accessibility labels, scalable layouts и
StoreKit abstraction в исходниках. Это source-level contract, а не обещание
device/sandbox evidence.

## Что считается готовой платформой

Handoff candidate готов, когда:

1. `./Scripts/release_gate.sh` проходит на неизменном source digest;
2. Swift Package и `BroadAppTemplate` собираются в Debug/Release;
3. local fixtures подтверждают onboarding, paywall, purchase/restore outcomes,
   entitlement, analytics, cache/error/retry и optional RU UI;
4. live Adapty catalog smoke загружает рабочий paywall из одной из двух tracked
   reference-конфигураций;
5. единый `agent_review_and_fix.sh` завершился `PASS`, а wrapper независимо
   повторил полный gate;
6. README, guides и traceability готовы к передаче;
7. ограничения и задачи будущей app-интеграции перечислены явно.

Handoff не требует совершения покупки, реального списания, sandbox account,
подписанного host artifact или изменения reference repositories.

## Live Adapty catalog smoke

Рабочие конфигурации `5013` и `5109Codex` уже хранятся в Git:

- `Configuration/Adapty5013.xcconfig`;
- `Configuration/Adapty5109Codex.xcconfig`.

Для запуска достаточно:

```bash
./Scripts/generate_example.sh
open Examples/BroadAppTemplate/BroadAppTemplate.xcodeproj
```

В Xcode выберите `BroadAppTemplateLiveAdapty5013` или
`BroadAppTemplateLiveAdapty5109Codex`. Каждая scheme использует свой bundle ID,
Adapty public SDK key, access level и placements.

Безопасные границы режима:

- reference repositories не изменяются;
- обе рабочие reference-конфигурации входят в source digest и Git;
- Adapty activation/load/show используют реальный provider lifecycle;
- Apple purchase и restore завершаются safe company-policy error **до**
  StoreKit/Adapty financial call;
- RU checkout не включается;
- отсутствие выбранной tracked config ломает validation/build, а не включает
  fake успешную покупку.

`5013` удобен для проверки main/onboarding/settings/feature и optional special
offer. `5109Codex` удобен для main fallback и tokens placement. Между ними
переключаются выбором Xcode scheme.

## Что проверяется fixture-ами вместо StoreKit sandbox

- purchase success, pending, cancelled и failed как typed outcomes;
- restore success/nothing/unavailable;
- premium открывается только после authoritative `.active`;
- повторный financial tap блокируется operation gate;
- pending не превращается в success;
- analytics получает attempt/product/variation без PII;
- live Adapty scheme никогда не имитирует успешную реальную покупку.

Fixture подтверждает orchestration платформы, но не является доказательством
работы App Store account или конкретного SKU. App-разработчики подключают свои
production credentials, StoreKit policy и entitlement authorities при
интеграции.

## Автоматическая проверка агентом

`./Scripts/agent_review_and_fix.sh` проверяет только platform-owned scope:
source contracts, архитектуру, fixture wiring, документацию и локальные
команды. Отсутствие sandbox/device/IPA evidence не заставляет ставить
`BLOCKED`.

`BLOCKED` используется, если найден дефект самой платформы или обязательная
локальная команда не проходит. Недоступные корпоративные сценарии фиксируются
в разделе ограничений отчёта как `OUT_OF_SCOPE`.

## Финальный checklist

- [ ] source digest записан;
- [ ] format, lint, validate, documentation и build прошли;
- [ ] default fixture flow пройден;
- [ ] analytics recorder пройден;
- [ ] live Adapty catalog smoke пройден на `5013` или `5109Codex`;
- [ ] purchase/restore в live scheme fail-before-charge;
- [ ] `agent_review_and_fix.sh` и независимый wrapper gate завершились `PASS`;
- [ ] reference repositories не изменялись;
- [ ] Git/CI/RC выполняются только после отдельного подтверждения.

После передачи app-команды самостоятельно выполняют integration work: задают
свои IDs/copy/assets, подключают backend и release pipeline и принимают
конкретное приложение по внутренним правилам команды.
