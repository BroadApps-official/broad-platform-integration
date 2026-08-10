# Текущий статус автоматической проверки

Текущий source snapshot:
`3242656f16f84ab330c52c8bf62c935546b8c45c61eac38723bc1441fe9c7589`.

## Единый рабочий процесс

Для проверки и автоматического исправления используется одна команда:

```bash
./Scripts/agent_review_and_fix.sh
```

Она:

1. запускает Codex с правилами из `AGENTS.md`;
2. проверяет contracts, privacy, документацию, format, lint и архитектуру;
3. собирает Swift Package и example в Debug/Release для iPhone;
4. compile-only собирает live Adapty configurations `5013` и `5109Codex`;
5. исправляет найденные platform-owned проблемы и повторяет проверку;
6. после ответа агента независимо запускает тот же полный gate;
7. сохраняет понятный результат в `AutomationReports/latest.md`.

Других обязательных agent workflows и отчётов нет.

## Подтверждённый scope

- только `BroadAppsIOSPlatform`;
- только iPhone (`TARGETED_DEVICE_FAMILY = 1`);
- reference projects не изменяются;
- test targets отсутствуют;
- StoreKit sandbox и реальные списания не входят в local acceptance;
- purchase/restore в live Adapty schemes завершаются до финансового SDK-вызова;
- интеграцию production-приложений выполняют app-разработчики позднее.

## Подключение

Package опубликован в приватном репозитории
`BroadApps-official/BroadCore`, ветка `vers_niiaz`. До
согласования version tag приложения подключают эту ветку через Swift Package
Manager либо используют локальную checkout-папку.

## Итог

`PASS` — 9 августа 2026 года после обновления визуальной документации и
fixture-режимов последовательно прошли `release_gate` и полный `agent_gate`.

Подтверждено для указанного snapshot:

- `Scripts/release_gate.sh` — `PASS`;
- `Scripts/agent_gate.sh` — `PASS`;
- SwiftFormat — `0/242` файлов требуют форматирования;
- SwiftLint — `0` нарушений;
- Xcode build matrix — `4/4`;
- live Adapty compile-only configurations — `2/2` (`5013` и `5109Codex`);
- documentation/link/asset validation проверяет девять настоящих iPhone PNG;
- fixture paywall подтверждён для `0/1/2/12` продуктов.

Подробный локальный runtime-отчёт создаётся в
`AgentChecks/AutomationReports/latest.md`. Этот файл намеренно не хранится в
Git: в репозитории фиксируется стабильный статус, а новый запуск всегда создаёт
свежий отчёт для текущей машины.

В рамках принятого local platform acceptance незакрытых проблем нет.
