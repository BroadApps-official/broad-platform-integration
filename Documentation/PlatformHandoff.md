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
- Swift Package и iPhone example в Debug/Release;
- компиляцию двух рабочих live Adapty configurations без финансовых операций.

## Перед commit

- полный gate закончился строкой
  `BroadApps iOS Platform agent gate passed.`;
- в `git diff` нет изменений reference-проектов и посторонних файлов;
- временные app-конфигурации не представлены как данные нового приложения;
- README и профильная документация соответствуют изменённому поведению.

## Подключение package

До появления version tag используется ветка:

```swift
.package(
    url: "https://github.com/BroadApps-official/BroadCore.git",
    branch: "vers_niiaz"
)
```

Проверка конкретного приложения выполняется отдельно: его app target должен
собираться в Debug/Release и проходить собственные safe fixture-сценарии.
