# Инструкция для ИИ: миграция старого приложения

Этот файл передают Codex, Claude или другому coding agent, когда существующее
iPhone-приложение нужно перевести со старого BroadApps monolith/local sources
на отдельные public module repositories.

Инструкция предназначена для `existing app`. Для нового приложения используйте
[App Creation Workflow](AppCreationWorkflow.md), а для работы без агента —
[ручную migration-инструкцию](MigrationGuide.md).

## Как использовать файл

В процессе участвуют три разных источника. Не смешивайте их:

| Источник | Роль | Можно изменять |
|---|---|---:|
| host repository открытого приложения | app rules, текущий код и `Documentation/AppIntegrationPlan.md` | да, только в границах подтверждённого stage |
| [`broad-platform-integration`](https://github.com/BroadApps-official/broad-platform-integration) | canonical read-only workflow и `Compatibility/current.yml` | нет |
| старый private `BroadApps-official/BroadCore` или local/copied sources | только evidence фактической legacy integration | нет до отдельного cleanup checkpoint |

1. Откройте агенту host repository конкретного приложения.
2. Убедитесь, что агент может прочитать public
   [`broad-platform-integration`](https://github.com/BroadApps-official/broad-platform-integration).
   Клонировать его внутрь host repository не нужно. Если GitHub недоступен,
   приложите экспорт этого файла и `Compatibility/current.yml`; иначе stage
   возвращает `APP MIGRATION · BLOCKED`.
3. Если `Documentation/AppIntegrationPlan.md` отсутствует, скопируйте
   canonical
   [`Templates/AppIntegrationPlan.md`](https://github.com/BroadApps-official/broad-platform-integration/blob/main/Documentation/Templates/AppIntegrationPlan.md)
   в host repository. Если Plan уже существует, не заменяйте его
   шаблоном: сохраните все решения, evidence, `BLOCKED` и
   подтверждённые checkpoint-ы, затем добавьте только отсутствующие
   поля актуального template и покажите diff.
4. Дайте агенту доступ к требованиям и read-only reference приложения.
5. Передайте стартовый prompt из конца этого файла. Предварительный скрытый
   контекст о platform repository не требуется: источник указан в prompt.
6. Агент выполняет один stage и останавливается на checkpoint.
7. Разработчик проверяет отчёт/diff и явно разрешает следующий stage.

Файл не разрешает настоящий purchase, restore, RU payment, signing,
публикацию или изменение Dashboard/backend данных.

## Обязательные входы

До изменения кода агент должен найти или пометить `BLOCKED`:

- canonical platform repository, его прочитанный commit SHA и `platform_set`;
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
   module. Сначала определи `Cutover topology`, затем переключай каждую
   `Atomic cutover group` целиком.
5. Не добавляй module «на будущее»: host подключает только используемые products.
6. Оставляй keys, URLs, placements, backend DTO/adapters, strings, assets и
   product decisions в host app.
7. Не удаляй legacy source до поиска usages, builds и developer review.
8. Не создавай `Tests/`, test targets, XCTest или Swift Testing.
9. Не выполняй настоящие purchase, restore или RU payment; не требуй Signing
   Team.
10. После паузы перечитывай Integration Plan, последний checkpoint и current
    diff; принятые stages повторно не генерируй.
11. Не перезаписывай существующий `Documentation/AppIntegrationPlan.md`
    пустым template. Добавляй только отсутствующие поля; непустое
    значение, принятое решение или checkpoint можно менять только
    после developer review.
12. Не обходи конфликт target names через `moduleAliases`, временный fork
    manifest или второго source owner без отдельного согласованного
    architecture plan.

## Универсальная модель cutover

Агент не выбирает порядок модулей по памяти. Он сначала читает фактические
package manifests, Xcode package references, products, target membership и
imports, а затем фиксирует одну из topology:

| `Cutover topology` | Как распознать | Что переключается |
|---|---|---|
| `atomic package cutover` | один legacy package/source owner объявляет несколько target names, которые конфликтуют с target names новых packages | минимальная группа actually used public products и их обязательных transitive dependencies одновременно с удалением legacy owner |
| `independent package boundaries` | legacy modules имеют разных owners, а промежуточный graph не содержит duplicate target names | каждая независимая boundary становится отдельной cutover group |
| `copied-source boundary` | platform `.swift`-файлы входят прямо в app target | новый product и исключение совпадающих files из target membership в одной group |
| `wrapper boundary` | app-owned wrapper скрывает legacy implementation | wrapper сохраняется как adapter, а owner его implementation переключается одной group |
| `mixed` | в одном host app присутствует несколько схем выше | отдельная group на каждую связанную область конфликтов |

Термины обязательны для аудита и Integration Plan:

- `Legacy owner` — точный package identity/URL/ref, local path, copied target
  membership или implementation за app wrapper, который сейчас владеет кодом;
- `Conflicting targets` — target/module names, которые имели бы двух owners в
  промежуточном graph; список берётся из manifests и project membership, а не
  только из imports;
- `Atomic cutover group` — минимальный набор package/project/source-membership
  изменений, после которого final graph снова имеет ровно одного owner для
  каждого target name;
- `Runtime slices after cutover` — отдельные behavior-срезы, которые агент
  мигрирует по одному только после принятого dependency switch.

Atomic group может включать несколько public repositories/products, но не
включает неиспользуемые modules «на будущее». Порядок снизу вверх относится к
release зависимых platform repositories; он не доказывает, что host app может
разрешить промежуточный graph со старым monolith и новым package одновременно.

## Stage 0 — только аудит

На этом stage запрещено менять Swift/project/package files.

Агент должен:

1. прочитать host repository rules, README и существующую app-документацию;
2. прочитать этот workflow и `Compatibility/current.yml` из canonical public
   `BroadApps-official/broad-platform-integration`, записать фактический commit
   SHA и `platform_set` в App Integration Plan;
3. определить legacy integration: package/local path/copied sources/wrapper;
4. отдельно найти private monolith URL `BroadApps-official/BroadCore`, Git URL
   rewrites и package references, которые могут вызвать credential prompt;
5. снять package/product/target-membership graph;
6. определить `Cutover topology`, каждый `Legacy owner`, `Conflicting targets`
   и candidate `Atomic cutover group`; если это нельзя доказать, вернуть
   `APP MIGRATION · BLOCKED`;
7. найти imports, construction points, adapters и composition root;
8. перечислить реально используемые BroadExtensions/Core/Monetization/UIFlows
   capabilities;
9. выполнить доступные baseline builds без исправления старых ошибок;
10. отделить pre-existing failures от migration blockers;
11. заполнить current state/gaps и cutover graph в
    `Documentation/AppIntegrationPlan.md`.

Финальный ответ stage:

```text
MIGRATION PREFLIGHT REVIEW REQUIRED
```

В ответе нужны current graph, `Cutover topology`, `Legacy owner`,
`Conflicting targets`, candidate `Atomic cutover group`, baseline evidence,
blockers и один следующий шаг. После ответа агент останавливается.

## Stage 1 — план без migration-кода

После подтверждения preflight агент обновляет Integration Plan:

- `Cutover topology` с evidence из manifests/project membership;
- точный `Legacy owner` и `Conflicting targets` для каждой области;
- одна или несколько `Atomic cutover group`: old references/files, которые
  удаляются вместе, реально используемые public products, exact candidate
  versions и обязательные transitive dependencies;
- порядок только между независимыми cutover groups; внутри atomic group
  промежуточных resolve/build нет;
- dependency-only changes отдельно от behavior changes;
- необходимые compile-only compatibility adaptations, если baseline иначе не
  компилируется после switch; intentional behavior change в group запрещён;
- `Runtime slices after cutover` и expected behavior;
- files/target membership, удаляемые на каждом шаге;
- expected final graph, resolve/build, functional и group-level rollback
  evidence;
- app-owned области, которые нельзя переносить;
- `BLOCKED` и владелец каждого недостающего решения.

Финальный ответ stage:

```text
MIGRATION PLAN REVIEW REQUIRED
```

До явного подтверждения package/project/Swift files не меняются.

## Stage 2 — одна cutover group

После подтверждения плана агент выбирает первую READY cutover group. Для
`independent package boundaries` это может быть один module boundary; для
`atomic package cutover` group может включать несколько repositories/products.

1. сверяет group с подтверждёнными `Legacy owner`, `Conflicting targets` и
   final graph в Integration Plan;
2. добавляет только запланированные public repositories/exact versions и
   products из compatibility catalog;
3. в том же diff удаляет весь запланированный old package/local reference или
   исключает совпадающие copied sources из target membership;
4. сохраняет app-owned wrapper как adapter, если topology помечена
   `wrapper boundary`;
5. применяет только заранее перечисленные compile-only adaptations, не меняя
   intentional runtime behavior и соседние features;
6. для atomic group выполняет все package/project changes вместе и не запускает
   resolve на заведомо неполном промежуточном graph;
7. перед resolve подтверждает, что каждый `Conflicting target` имеет ровно
   одного owner в final graph;
8. выполняет package resolve только для final graph, затем Debug/Release
   Simulator и generic iOS compile;
9. показывает полный group diff, build evidence и единый rollback;
10. обновляет только строки этой cutover group в Integration Plan.

Если фактический resolve открывает новый conflict или group не сохраняет
baseline compile, агент откатывает всю group, обновляет Plan и возвращает
`APP MIGRATION · BLOCKED` либо новый `MIGRATION PLAN REVIEW REQUIRED`. Он не
проталкивает по одному module из atomic group и не маскирует конфликт aliases.

Финальный ответ stage:

```text
DEPENDENCY SWITCH REVIEW REQUIRED
```

## Stage 3 — один runtime slice after cutover

После подтверждения dependency switch агент мигрирует ровно один runtime
slice. Даже если cutover group включала несколько products, behavior не
объединяется в один большой rewrite:

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

## Stage 4 — cleanup legacy implementation

После подтверждения всех runtime slices выбранной cutover group агент:

1. ищет оставшиеся legacy imports, constructions, compatibility bridges,
   target membership и package refs;
2. удаляет только доказанный legacy implementation; app wrapper, который Plan
   сохранил как adapter, не удаляет;
3. повторяет builds и safe probes;
4. подтверждает, что app-owned adapters/configuration сохранены;
5. фиксирует rollback commit и обновляет Plan/changelog.

Финальный ответ stage:

```text
LEGACY CLEANUP REVIEW REQUIRED
```

Если usages остались, cleanup возвращает `BLOCKED`, а не скрывает проблему.

## Stage 5 — следующая cutover group или acceptance

Если остаётся READY независимая cutover group, агент возвращается к Stage 2
только после подтверждения cleanup. Он не создаёт «следующий module» внутри
уже принятой atomic group. Когда cutover groups и runtime slices закончились,
он проверяет:

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

Источники не взаимозаменяемы:
- HOST REPOSITORY — текущий открытый repository приложения; здесь находится
  app-код и сюда разрешено записывать результаты подтверждённого stage;
- PLATFORM REPOSITORY — canonical read-only public repository
  https://github.com/BroadApps-official/broad-platform-integration;
- LEGACY SOURCE — private BroadApps-official/BroadCore, local package или
  copied sources; это только evidence текущей integration, не новый package.

Обязательно прочитай из host repository:
1. AGENTS.md/CLAUDE.md и README;
2. Documentation/AppIntegrationPlan.md.

Если Documentation/AppIntegrationPlan.md отсутствует, создай его только из
canonical template:
https://github.com/BroadApps-official/broad-platform-integration/blob/main/Documentation/Templates/AppIntegrationPlan.md
Если Documentation/AppIntegrationPlan.md уже существует, не заменяй его
пустым template. Сохрани все непустые значения, evidence, `BLOCKED`,
решения и подтверждённые checkpoint-ы. Сравни структуру с canonical
template и добавь только отсутствующие поля. Если нужно удалить или
заменить существующее значение, не делай это на Stage 0: покажи diff
и верни MIGRATION PREFLIGHT REVIEW REQUIRED.
Другие app-файлы на Stage 0 не создавай и не меняй.

Обязательно прочитай из PLATFORM REPOSITORY:
3. Documentation/LegacyAppMigrationAgent.md;
4. Compatibility/current.yml.

Запиши в AppIntegrationPlan.md URL platform repository, фактический commit SHA,
platform_set и найденный legacy source. Если PLATFORM REPOSITORY,
LegacyAppMigrationAgent.md или Compatibility/current.yml недоступны, ничего не
угадывай: верни APP MIGRATION · BLOCKED с точным отсутствующим входом. Не
используй private BroadCore как источник новых package versions.

Сейчас выполни только Stage 0 — аудит. Не меняй Swift, Xcode project,
Package.swift/Package.resolved или source membership. Не создавай новый app и
не переписывай существующие features.

Определи current dependency graph, `Cutover topology`, каждый `Legacy owner`,
`Conflicting targets`, candidate `Atomic cutover group`, фактически
используемые modules, baseline build results и blockers. Обнови только current
state/gaps и cutover graph в AppIntegrationPlan.md.

Закончи MIGRATION PREFLIGHT REVIEW REQUIRED и остановись до моего явного
подтверждения.
```

## Prompt для продолжения после checkpoint

```text
Продолжи legacy migration с последнего явно подтверждённого checkpoint.

Из host repository перечитай Documentation/AppIntegrationPlan.md и current
diff. Из canonical public
https://github.com/BroadApps-official/broad-platform-integration перечитай
Documentation/LegacyAppMigrationAgent.md на commit SHA, записанном в Plan.
Сверь platform_set с Compatibility/current.yml. Если источник/ref недоступен,
остановись с APP MIGRATION · BLOCKED.

Назови подтверждённый checkpoint и следующий stage. Выполни только этот stage,
не повторяй принятые изменения и не затрагивай соседние modules/slices. При
blocker-е обнови Plan и остановись с точным REVIEW REQUIRED или
APP MIGRATION · BLOCKED.
```

## Связанные документы

- [Ручная миграция](MigrationGuide.md)
- [Integration Plan template](Templates/AppIntegrationPlan.md)
- [Agent Preflight](AgentPreflight.md)
- [Project Delivery](ProjectDelivery.md)
- [Platform Handoff](PlatformHandoff.md)
