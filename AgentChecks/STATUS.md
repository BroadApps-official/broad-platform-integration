# Последняя подтверждённая проверка платформы

## Результат

`PASS` — полный local gate прошёл 17 августа 2026 года.

Проверено:

- архитектурные и продуктовые правила;
- автоматическая матрица Adapty experiment contracts;
- privacy manifest и документация;
- SwiftFormat и SwiftLint;
- Swift Package и iPhone example в Debug/Release;
- две live Adapty configurations без запуска финансовых операций.

## Как получить свежий результат после своих изменений

С автоматическим исправлением:

```bash
./Scripts/agent_review_and_fix.sh
```

Только проверить:

```bash
bash Scripts/agent_gate.sh
```

Свежий локальный отчёт появится в
`AgentChecks/AutomationReports/latest.md`. Успешный terminal output заканчивается
строкой `BroadApps iOS Platform agent gate passed.`

<details>
<summary><strong>Технический source snapshot последнего PASS</strong></summary>

`155c5532e48849076cb3ec1da07db426bf46704df9ea2d18bb10523ba4e53676`

</details>
