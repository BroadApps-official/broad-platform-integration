# Текущий статус автоматической проверки

Текущий source snapshot:
`699e99b54d875f97a71c2d7f9f4ca8e6193c8991f63e815fa3755c25ae738136`.

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

## Итог

`PASS` — функциональные platform contracts реализованы. Для указанного source
snapshot успешно прошли local engineering gate и обе compile-only live Adapty
configurations. Старые отдельные handoff-проверки не требуются.
