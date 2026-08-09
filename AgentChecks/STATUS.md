# Текущий статус автоматической проверки

Текущий source snapshot:
`3372422a8bb87fa7087dfaaf0d6a22957213fb9648c2e39ef85d70574c73ceab`.

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
`BroadApps-official/BroadCore`, ветка `agent/broadapps-ios-platform`. До
согласования version tag приложения подключают эту ветку через Swift Package
Manager либо используют локальную checkout-папку.

## Итог

Функциональные platform contracts реализованы, GitHub-ветка опубликована.
Documentation и validation для указанного snapshot проверяются в рамках шага 2;
финальный полный agent review-and-fix cycle выполняется отдельным шагом 3.
