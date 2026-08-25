# Инструкция для ИИ: миграция старого приложения

Этот файл передают Codex, Claude или другому coding agent, когда существующее
iPhone-приложение нужно перевести со старого BroadApps monolith/local sources
на отдельные public module repositories.

Инструкция предназначена для `existing app`. Для нового приложения используйте
[App Creation Workflow](AppCreationWorkflow.md), а для работы без агента —
[ручную migration-инструкцию](MigrationGuide.md).

## Как использовать файл

1. Скопируйте
   [`Templates/AppIntegrationPlan.md`](Templates/AppIntegrationPlan.md) в host
   repository как `Documentation/AppIntegrationPlan.md`.
2. Дайте агенту доступ к host repository, требованиям и read-only reference.
3. Передайте стартовый prompt из конца этого файла.
4. Агент выполняет один stage и останавливается на checkpoint.
5. Разработчик проверяет отчёт/diff и явно разрешает следующий stage.

Файл не разрешает настоящий purchase, restore, RU payment, signing,
публикацию или изменение Dashboard/backend данных.

## Обязательные входы

До изменения кода агент должен найти или пометить `BLOCKED`:

- app target, workspace/project и supported configurations;
- текущий способ подключения старой платформы;
- package graph, target membership и local/copied sources;
- composition root и фактический dependency ownership;
- requirements, design/reference и screen map;
- backend/SDK contracts, placements, products, legal/support decisions;
- текущие build results и известные regressions;
- выбранный platform set из `Compatibility/current.yml`.

Unknown endpoint, screen, feature rule или app-owned configuration нельзя
угадывать. Fixture не считается production evidence.

## Жёсткие правила агента

1. Не создавай новое приложение или второй target вместо миграции existing app.
2. Не переписывай всё приложение и не делай один большой migration commit.
3. Не меняй подтверждённое behavior одновременно с dependency switch.
4. Не подключай два package/source owner, экспортирующих одинаковый Swift
   module. Переключай boundary атомарно.
5. Не добавляй module «на будущее»: host подключает только используемые products.
6. Оставляй keys, URLs, placements, backend DTO/adapters, strings, assets и
   product decisions в host app.
7. Не удаляй legacy source до поиска usages, builds и developer review.
8. Не создавай `Tests/`, test targets, XCTest или Swift Testing.
9. Не выполняй настоящие purchase, restore или RU payment; не требуй Signing
   Team.
10. После паузы перечитывай Integration Plan, последний checkpoint и current
    diff; принятые stages повторно не генерируй.

## Stage 0 — только аудит

На этом stage запрещено менять Swift/project/package files.

Агент должен:

1. прочитать repository rules, README и существующую документацию;
2. определить legacy integration: package/local path/copied sources/wrapper;
3. отдельно найти private monolith URL `BroadApps-official/BroadCore`, Git URL
   rewrites и package references, которые могут вызвать credential prompt;
4. снять package/product/target-membership graph;
5. найти imports, construction points, adapters и composition root;
6. перечислить реально используемые BroadExtensions/Core/Monetization/UIFlows
   capabilities;
7. выполнить доступные baseline builds без исправления старых ошибок;
8. отделить pre-existing failures от migration blockers;
9. заполнить current state/gaps в `Documentation/AppIntegrationPlan.md`.

Финальный ответ stage:

```text
MIGRATION PREFLIGHT REVIEW REQUIRED
```

В ответе нужны current graph, legacy ownership, target modules, baseline
evidence, blockers, duplicate-module risks и один следующий шаг. После ответа
агент останавливается.

## Stage 1 — план без migration-кода

После подтверждения preflight агент обновляет Integration Plan:

- target product и exact candidate version для каждой old dependency;
- порядок switch снизу вверх;
- dependency-only changes отдельно от behavior changes;
- vertical slices и expected behavior;
- files/target membership, удаляемые на каждом шаге;
- build, functional и rollback evidence;
- app-owned области, которые нельзя переносить;
- `BLOCKED` и владелец каждого недостающего решения.

Финальный ответ stage:

```text
MIGRATION PLAN REVIEW REQUIRED
```

До явного подтверждения package/project/Swift files не меняются.

## Stage 2 — один dependency boundary

После подтверждения плана агент выбирает первый READY boundary:

1. добавляет public repository/version из compatibility catalog;
2. заменяет private monolith URL на нужный `BroadApps-official/broad-*-ios.git`
   URL без password, token и API key;
3. добавляет product нужному iPhone target;
4. атомарно удаляет конфликтующий old product/local reference или исключает
   совпадающие copied sources;
5. не меняет соседние features;
6. выполняет package resolve, Debug/Release Simulator и generic iOS compile;
7. показывает dependency diff и rollback;
8. обновляет только строки этого boundary в Integration Plan.

Если old package содержит несколько одноимённых products и частичный switch
невозможен, агент останавливается и предлагает минимальный dependency-only
switch конфликтующих references. Runtime slices остаются раздельными.

Финальный ответ stage:

```text
DEPENDENCY SWITCH REVIEW REQUIRED
```

## Stage 3 — один вертикальный срез

После подтверждения dependency switch агент мигрирует ровно один slice:

```text
View → ViewModel → use case → repository/adapter → SDK/backend
```

Он сохраняет app-owned UI/configuration и проверяет loading/content/empty/error,
retry/offline, cancellation и duplicate actions. Для monetization нельзя
фильтровать provider products, выдавать premium по одному purchase response или
разрешать RU Billing без требуемого fresh evidence.

Финальный ответ stage:

```text
MIGRATION SLICE REVIEW REQUIRED
```

Ответ содержит expected/current/evidence и просит разработчика лично проверить
изменённый flow. Следующий slice не начинается автоматически.

## Stage 4 — удаление legacy owner

После подтверждения всех slices выбранного module агент:

1. ищет оставшиеся imports, constructions, target membership и package refs;
2. удаляет только доказанный old owner;
3. повторяет builds и safe probes;
4. подтверждает, что app-owned adapters/configuration сохранены;
5. фиксирует rollback commit и обновляет Plan/changelog.

Финальный ответ stage:

```text
LEGACY CLEANUP REVIEW REQUIRED
```

Если usages остались, cleanup возвращает `BLOCKED`, а не скрывает проблему.

## Stage 5 — следующий module или acceptance

Если остаётся READY module, агент возвращается к Stage 2 только после
подтверждения cleanup. Когда legacy owners закончились, он проверяет:

- exact versions совпадают с compatibility catalog;
- local paths/copied platform sources отсутствуют;
- Debug/Release Simulator и unsigned generic iOS compile прошли;
- app flows проверены в доступных safe scenarios;
- platform gate запущен отдельно, только если менялась сама платформа;
- реальные financial operations не запускались;
- changelog объясняет, что изменено и почему.

Финальный статус:

```text
READY FOR QA
```

Если обязательный app-owned contract неизвестен, вернуть:

```text
APP MIGRATION · BLOCKED
```

и назвать одно конкретное действие владельца blocker-а.

## Стартовый prompt для Codex или Claude

```text
Ты мигрируешь существующее iPhone-приложение со старого BroadApps
monolith/local sources на независимые public modules.

Обязательно прочитай:
1. repository AGENTS.md/CLAUDE.md и README;
2. Documentation/LegacyAppMigrationAgent.md;
3. Documentation/AppIntegrationPlan.md;
4. актуальный Compatibility/current.yml платформы.

Сейчас выполни только Stage 0 — аудит. Не меняй Swift, Xcode project,
Package.swift/Package.resolved или source membership. Не создавай новый app и
не переписывай существующие features.

Определи current dependency graph, вид legacy integration, фактически
используемые modules, duplicate-module risks, baseline build results и
blockers. Обнови только current state/gaps в AppIntegrationPlan.md.

Закончи MIGRATION PREFLIGHT REVIEW REQUIRED и остановись до моего явного
подтверждения.
```

## Prompt для продолжения после checkpoint

```text
Продолжи legacy migration с последнего явно подтверждённого checkpoint.

Перечитай Documentation/AppIntegrationPlan.md, current diff и
Documentation/LegacyAppMigrationAgent.md. Назови подтверждённый checkpoint и
следующий stage. Выполни только этот stage, не повторяй принятые изменения и не
затрагивай соседние modules/slices. При blocker-е обнови Plan и остановись с
точным REVIEW REQUIRED или APP MIGRATION · BLOCKED.
```

## Связанные документы

- [Ручная миграция](MigrationGuide.md)
- [Integration Plan template](Templates/AppIntegrationPlan.md)
- [Agent Preflight](AgentPreflight.md)
- [Project Delivery](ProjectDelivery.md)
- [Platform Handoff](PlatformHandoff.md)
