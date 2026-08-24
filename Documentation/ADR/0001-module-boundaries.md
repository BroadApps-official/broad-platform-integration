# ADR-0001: Границы модулей платформы

- Статус: принято
- Дата: 2026-08-09
- Дополнено: [ADR-0006](0006-federated-public-repositories.md)

## Контекст

Несколько приложений должны переиспользовать startup, monetization и UI flows, но сохранять собственные тексты, assets, backend configuration и продуктовые решения. Монолитный shared target быстро смешивает SDK, SwiftUI и бизнес-логику, усложняет перенос между приложениями и позволяет screen напрямую управлять сетью/покупкой.

## Решение

Платформа состоит из трёх основных library products и одного
независимого product с однонаправленными зависимостями:

```text
BroadCore
   ↑
BroadMonetization
   ↑
BroadUIFlows
   ↑
Host App

BroadExtensions ← Host App (опционально, независимо)
```

Точный Package graph:

- `BroadCore` не зависит от других platform modules;
- `BroadMonetization` зависит от `BroadCore`;
- `BroadUIFlows` зависит от `BroadCore` и `BroadMonetization`;
- `BroadExtensions` не зависит от других модулей;
- Host App подключает только нужные ему repositories/products и создаёт
  runtime-зависимости только в composition root;
- `broad-platform-integration` фиксирует проверенный набор версий,
  но не является обязательной dependency host app.

Внутри каждого feature соблюдаются Clean Architecture и MVVM:

```text
Presentation → Application → Domain
                     ↓
                   Data → Infrastructure
```

Разрешённая ответственность:

| Область | Владелец |
|---|---|
| bootstrap, cache, retry, logging, shared state, ATT boundary | `BroadCore` |
| placements, paywall data, purchase/restore, entitlement, RU, analytics | `BroadMonetization` |
| AppFlow, onboarding, loader/error/retry, paywall SwiftUI | `BroadUIFlows` |
| тексты, assets, real IDs/URL/keys, feature policies, DI | Host App |
| SDK types, wire DTO, URLSession/StoreKit calls | соответствующий Infrastructure layer |

Дополнительные ограничения:

- Domain/Data не импортируют SwiftUI;
- Presentation не импортирует Adapty/StoreKit;
- View не обращается к Swinject и не создаёт repository/use case/ViewModel;
- SDK/wire types не выходят за adapter boundary;
- продуктовые строки, SKU, provider placement ID и URLs не хардкодятся в platform UI;
- dependencies передаются через `init`, global service locator запрещён.

## Последствия

Положительные:

- Core можно использовать без monetization/UI;
- provider/backend adapter заменяется без изменения Domain и screen;
- app-specific дизайн и configuration не загрязняют package;
- архитектурные нарушения проверяются скриптом и SwiftLint;
- независимые направления можно развивать параллельно.

Цена решения:

- больше маленьких contracts/mappers;
- composition root приложения становится явной точкой сборки;
- новая feature требует заранее выбрать правильный owner/module;
- изменение public Domain-контракта требует согласования всех consumers.

## Отклонённые варианты

### Один общий target

Отклонён: позволяет UI напрямую зависеть от SDK и создаёт циклическое знание между startup, оплатой и screens.

### DI-container внутри View

Отклонён: зависимости становятся скрытыми, preview/manual fixtures трудно собирать, lifecycle неочевиден.

### SDK models как публичный API

Отклонён: provider upgrade распространяется на весь UI и приложения, альтернативный backend становится дорогим.

### App-specific configuration внутри package

Отклонён: shared code начинает содержать реальные IDs/URL/keys и теряет переиспользуемость.

## Проверка решения

```bash
./Scripts/check_architecture.sh
./Scripts/lint.sh
./Scripts/build.sh
```

Исходник схемы: [module-dependencies.mmd](../Diagrams/module-dependencies.mmd). Практическое подключение: [Getting Started](../GettingStarted.md).
