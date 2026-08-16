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

`898c09682de122416e6f01f26ed82fdd7374d26b60dc5b45cb68707a6e68825a`

</details>
