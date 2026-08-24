# ADR-0006: Публичные репозитории модулей

- Статус: принято
- Дата: 2026-08-24
- Дополняет: [ADR-0001](0001-module-boundaries.md)

## Контекст

Один repository с четырьмя library products удобен для атомарной разработки,
но затрудняет независимые review, release и подключение. Изменение
документации или одной feature выглядит как изменение всей платформы.
Корневой README содержит полную книгу и поэтому плохо работает как точка
входа.

## Решение

Каждый Swift-модуль получает отдельный публичный repository:

| Repository | Product | Прямые platform dependencies |
|---|---|---|
| `broad-extensions-ios` | `BroadExtensions` | нет |
| `broad-core-ios` | `BroadCore` | нет |
| `broad-monetization-ios` | `BroadMonetization` | `broad-core-ios` |
| `broad-ui-flows-ios` | `BroadUIFlows` | `broad-core-ios`, `broad-monetization-ios` |

Дополнительно:

- `broad-platform-integration` хранит compatibility catalog, интеграционный
  iPhone example и cross-module probes;
- `broad-docs` хранит исходники публичного сайта, поиск и
  агрегированные DocC-архивы;
- существующие Markdown-документы не удаляются: они остаются
  редактируемыми исходниками, а сайт даёт вторую удобную точку чтения;
- все repositories, issues, pull requests, Actions и сайт публичны.

## Правило подключения host app

Host app подключает **любой нужный модуль**. Единый `BroadPlatform`
не является обязательной точкой входа. Например:

- utility-only app подключает только `BroadExtensions`;
- app со своим UI и monetization подключает `BroadMonetization`;
- app с готовыми flow подключает `BroadUIFlows`;
- app может добавить `BroadCore` или `BroadExtensions` напряму, если их public API
  импортируется в app target.

SwiftPM транзитивно разрешает нижележащие module dependencies.
Compatibility catalog нужен для выбора заранее проверенной комбинации,
а не для принудительного подключения всей платформы.

## Версии и совместимость

- каждый module repository выпускает свои SemVer tags;
- internal dependencies задаются диапазоном `upToNextMajor`;
- integration repository фиксирует точные версии после полной
  cross-module проверки;
- breaking public API change требует major release владеющего модуля;
- каталог хранит минимальную iOS/Swift toolchain и статус проверки.

## Проверка без unit tests

По решению владельца платформы `Tests/`, test targets, XCTest и Swift
Testing не добавляются. Их место занимают:

- static architecture/privacy/documentation contracts;
- `swift build` и generic iOS compile;
- исполняемые fixture/probe-сценарии;
- отдельный iPhone sandbox модуля;
- интеграционный example для проверенного набора версий.

Gate обязан отклонять появление test targets или test frameworks, а не просто не
запускать их.

## Последствия

Положительные:

- review и release ограничены затронутым модулем;
- host app не получает ненужные SDK и UI;
- документы можно искать по ключевым словам и править через обычный PR;
- каждый модуль можно собрать и изучить отдельно.

Цена решения:

- cross-repository change требует порядка release снизу вверх;
- версии нужно явно согласовывать в compatibility catalog;
- нужно раздельно поддерживать CI, README, DocC и sandbox каждого модуля;
- межмодульная сборка остаётся обязательной перед публикацией каталога.

## Отклонённые варианты

### Оставить всё в одном repository

Отклонён: не даёт изолированный review/release и сохраняет перегруженную
точку входа.

### Обязать host app подключать umbrella package

Отклонён: противоречит требованию подключать любой модуль по надобности и
снова расширяет blast radius каждого обновления.

### Перенести всю документацию только на сайт

Отклонён: Markdown рядом с кодом нужен для versioned review и offline-работы.
Сайт дополняет его, а не заменяет.

## Порядок внедрения

1. Зафиксировать contracts, manifests и проверки.
2. Опубликовать docs-site, не удаляя текущие guides.
3. Переносить модули снизу вверх: Extensions → Core → Monetization → UIFlows.
4. После каждого модуля пройти standalone gate, sandbox compile и integration gate.
5. Только после этого обновить compatibility catalog и release tags.

[Полный план и checklist](../FederatedRepositories.md).
