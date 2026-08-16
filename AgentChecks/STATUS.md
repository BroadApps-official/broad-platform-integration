# Последняя подтверждённая проверка платформы

## Результат

`PASS` — полный local gate прошёл 16 августа 2026 года.

Проверено:

- архитектурные и продуктовые правила;
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

`a0d1a47153668b30c5260e3dae9735f9d90734a649b18cc339d324f2d89613e5`

</details>
