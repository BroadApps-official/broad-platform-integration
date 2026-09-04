# Что сделать перед передачей изменений платформы

Эта инструкция нужна только тогда, когда разработчик менял файлы внутри
`BroadAppsIOSPlatform`. При обычном подключении package к новому приложению
используйте checklist самого приложения из главного README.

## Вариант 1 — Codex проверяет и исправляет

Из корня платформы:

```bash
./Scripts/agent_review_and_fix.sh --doctor
./Scripts/agent_review_and_fix.sh
```

Первая команда проверяет окружение. Вторая запускает Codex с готовыми правилами,
разрешает ему исправить platform-owned ошибки и затем повторяет полный gate ещё
раз независимо.

Результат сохраняется в:

```text
AgentChecks/AutomationReports/latest.md
```

## Вариант 2 — проверить вручную

```bash
bash Scripts/agent_gate.sh
```

Этот скрипт ничего не исправляет. Если он остановился на ошибке:

1. исправьте первую причину;
2. после Swift-правок выполните `bash Scripts/format.sh`;
3. снова запустите `bash Scripts/agent_gate.sh`;
4. повторяйте до полного `PASS`.

## Что подтверждает platform gate

- границы модулей и обязательные архитектурные правила;
- ATT, onboarding, paywall и entitlement guardrails;
- RU Billing, tokens, recovery и поведение при плохой сети;
- SwiftFormat, SwiftLint, privacy manifest, документацию и assets;
- Swift Package, iPhone Simulator example в Debug/Release и generic iOS compile
  без подписи;
- компиляцию двух рабочих live Adapty configurations без финансовых операций.

Это локальный platform/example scope. Для runtime-проверки запущенного example
используйте `bash Scripts/stream_example_logs.sh`; UI/Debug Status остаётся
источником итогового результата, а поток объясняет порядок safe typed событий.

## Перед commit

- полный gate закончился строкой
  `BroadApps iOS Platform agent gate passed.`;
- в `git diff` нет изменений reference-проектов и посторонних файлов;
- временные app-конфигурации не представлены как данные нового приложения;
- README и профильная документация соответствуют изменённому поведению.

## Подключение package

Host app подключает release из `Compatibility/current.yml`, а не рабочую ветку
платформы. Для текущего verified set BroadCore подключается так:

```swift
.package(
    url: "https://github.com/BroadApps-official/broad-core-ios.git",
    exact: "1.2.0"
)
```

Private `BroadApps-official/BroadCore`, branch `vers_niiaz` и local integration
checkout не являются источниками release dependency. Если catalog изменился,
сначала возьмите новый exact tag из `Compatibility/current.yml` и повторите
module/integration acceptance.

Проверка конкретного приложения выполняется отдельно: его app target должен
собираться в Debug/Release и проходить собственные safe fixture-сценарии.
