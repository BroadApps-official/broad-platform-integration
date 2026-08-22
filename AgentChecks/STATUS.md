# Последняя подтверждённая проверка платформы

## Результат

`PASS` — полный local gate прошёл 22 августа 2026 года.

Проверено:

- архитектурные и продуктовые правила;
- автоматические матрицы Remote Config и Adapty experiment contracts;
- special offer для текущего ответа Adapty, `false`, кеша платформы,
  резерва на `main` и доверенного серверного времени;
- RU Billing gate для текущего ответа Adapty и кеша платформы;
- privacy manifest, ссылки, изображения и актуальность главного README;
- SwiftFormat и SwiftLint: 278 Swift-файлов, 0 нарушений;
- Swift Package и iPhone example в Debug/Release;
- две live Adapty configurations без запуска финансовых операций;
- семь локальных Remote Config fixtures на iPhone 17 Pro Simulator.

Настоящие purchase, restore и RU-платежи не запускались.

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

`2b01c3ce6e657bfcb3f91ddaf3dae993ef153651c86024898fcbce075ec95a69`

</details>
