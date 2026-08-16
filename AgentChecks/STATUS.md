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

`6249ec462df1b3594d86982a688db8f5d0a011cdb823d5927c378d2702a3ef88`

</details>
