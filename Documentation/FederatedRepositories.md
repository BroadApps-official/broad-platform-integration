# Федерация repositories BroadApps iOS

Этот документ — исполняемый план переноса и постоянный contract между
публичными repositories. Архитектурное решение зафиксировано в
[ADR-0006](ADR/0006-federated-public-repositories.md).

## Целевая карта

```text
Host App
 ├─ broad-extensions-ios      (optional, standalone)
 ├─ broad-core-ios            (optional, foundation)
 ├─ broad-monetization-ios    (brings compatible BroadCore)
 └─ broad-ui-flows-ios        (brings compatible Monetization + Core)

broad-platform-integration
 ├─ exact known-good module versions
 ├─ BroadAppTemplate
 └─ cross-module probes and release evidence

broad-docs
 ├─ editable Markdown/MDX sources
 ├─ generated DocC links
 └─ public site + keyword search
```

Host app не обязано подключать integration repository или все модули.

## Владение кодом и документами

| Артефакт | Canonical owner | Куда агрегируется |
|---|---|---|
| Swift-исходник модуля | repository модуля | integration build |
| README и getting started модуля | repository модуля | docs-site navigation |
| DocC catalog и public API | repository модуля | docs-site / DocC hosting |
| Общие architecture/how-to guides | `broad-docs` | public site |
| Compatibility matrix | `broad-platform-integration` | docs-site |
| iPhone module sandbox | repository модуля | module gate |
| Целостный example | `broad-platform-integration` | integration gate |

У каждой страницы сайта есть ссылка `Edit this page`. Исходник меняется
обычным public pull request, а не через закрытую CMS.

## Как host app выбирает модули

| Задача app | Подключить напрямую | Что придёт транзитивно |
|---|---|---|
| Только extensions | `BroadExtensions` | ничего |
| Bootstrap/cache/logging | `BroadCore` | Swinject |
| Свой UI поверх монетизации | `BroadMonetization` | compatible `BroadCore`, Adapty, Swinject |
| Готовые onboarding/paywall/AppFlow | `BroadUIFlows` | compatible Monetization, Core, Adapty, Swinject |
| Extensions плюс любой flow | нужный модуль + `BroadExtensions` | по graph выше |

Если app импортирует public API нижележащего модуля напрямую, этот product
тоже указывается в app target. Compatibility matrix показывает набор,
который уже прошёл общую проверку.

## Порядок cross-repository change

1. Описать минимальное public API и владельца изменения.
2. Изменить самый нижний module repository.
3. Пройти его `module_gate.sh` и sandbox compile.
4. Выпустить SemVer tag.
5. Поднять dependency range в вышележащем модуле и повторить gate.
6. Обновить exact versions integration repository и пройти full integration gate.
7. Обновить compatibility catalog, changelog и docs-site.

Нельзя сначала выпустить верхний модуль, а потом пытаться подобрать
ему ещё не опубликованную dependency.

## Миграционные фазы и acceptance

| Фаза | Результат | Статус / проверка |
|---|---|---|
| 0. Baseline | чистый current tree | ✅ полный legacy gate PASS |
| 1. Contracts | ADR, ownership, compatibility schema | ✅ docs/contracts gate PASS |
| 2. Docs | public editable site | ✅ build, link/search, anonymous access, Edit this page |
| 3. Extensions | standalone public package | ✅ `1.0.0`, module/remote/release/integration gates PASS |
| 4. Core | standalone public package | ✅ `1.0.0`, module/remote/release/integration gates PASS |
| 5. Monetization | package с Core dependency | ✅ `1.0.0`, module/remote/release/integration gates PASS |
| 6. UIFlows | package с Core/Monetization | ✅ `1.0.0`, Gallery/module/remote/release gates PASS |
| 7. Cutover | integration repository и public releases | ✅ public repo, clean-runner CI и clean-clone acceptance PASS |

На каждой фазе проверяются:

- нет `Tests/`, test targets, XCTest и Swift Testing;
- repository public, clone без credentials работает;
- `Package.swift` объявляет только разрешённые platform dependencies;
- public API и module ownership не расширились случайно;
- README, DocC, links и assets валидны;
- package собирается для iOS 17+;
- runtime probe завершается с PASS без покупок/restore/RU payment;
- integration repo собирается с теми же versions.

## Definition of Done

- шесть целевых repositories публичны;
- четыре module packages собираются из clean clone;
- каждый модуль имеет README, license, changelog, DocC, module gate и iPhone sandbox;
- integration repository фиксирует и проверяет точную комбинацию;
- документация осталась в repositories и дополнительно опубликована на сайте;
- поиск по ключевым словам на сайте работает;
- release tags и compatibility catalog совпадают;
- ни в одном repository нет test targets/frameworks;
- в каждом README есть прямой путь для редактирования docs.

Связанные документы:
[release policy](ModuleReleasePolicy.md), [architecture](Architecture.md),
[migration guide](MigrationGuide.md).
