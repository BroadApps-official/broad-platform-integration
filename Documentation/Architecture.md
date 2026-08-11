# Архитектура

BroadApps iOS Platform состоит из трёх основных модулей и одного
независимого набора расширений. Зависимости идут только внутрь:

```text
Приложение → BroadUIFlows
BroadUIFlows → BroadMonetization
BroadUIFlows → BroadCore
BroadMonetization → BroadCore
Приложение ⇢ BroadExtensions (опционально)
BroadExtensions → ни от кого не зависит
```

Простое правило: верхний слой может знать о нижнем, но нижний не должен
знать о верхнем. Например, `BroadCore` никогда не импортирует UI или монетизацию.

## BroadCore

`BroadCore` хранит общую основу:

- порядок запуска приложения;
- кеш;
- состояния загрузки, ошибки и повтора;
- ограничения по времени;
- безопасное логирование;
- адаптер ATT.

`BroadCore` не зависит от `BroadMonetization` и `BroadUIFlows`.

### Запуск

Bootstrap Engine — это `actor`, который выполняет шаги запуска. Приложение заранее
передаёт ему готовые `Sendable`-шаги. Критические шаги заканчиваются до открытия
первого экрана. Фоновые шаги начинаются только после этого.

### Кеш и постоянное состояние

`CacheRepositoryProtocol` и типизированные модели описывают общие правила кеша.
`VersionedJSONCacheRepository` кодирует данные и проверяет срок их годности.
`UserDefaultsKeyValueStore` подходит для небольших снимков. Если позже понадобится
файловое хранилище, оно просто реализует `KeyValueStoreProtocol` — менять feature-код не нужно.

Прогресс AppFlow — это не кеш. Он хранится отдельно через `KeyValueStoreProtocol` в
`com.broadapps.platform.state`. Кеш живёт в `com.broadapps.platform.cache` и имеет TTL.
Чекпоинты AppFlow не имеют TTL и не удаляются вместе с устаревшим кешем.

### Логи

Наружу выходят только `BroadLoggerProtocol` и закрытая модель `BroadLogEvent`.
`OSLogBroadLogger` — единственный адаптер, которому разрешён импорт `OSLog`.
`NoOpBroadLogger` — безопасный вариант по умолчанию. В логи не попадают тексты приложения,
полезная нагрузка, ключи и raw SDK errors.

### Состояние экрана

`LoadableState<Value>` хранит только состояние. Он не знает о SwiftUI, Combine, DI или `Task`.
При обновлении или ошибке он может сохранить ранее показанный контент, если это разрешает
конкретная feature. `AppBootstrapState` по-прежнему описывает запуск, а `CacheReadResult` — свежесть
данных. ViewModel или Application-слой преобразует их в `LoadableState`.

## BroadMonetization

`BroadMonetization` содержит placements, Adapty paywalls/products, remote config,
purchase/restore, Entitlement Engine, Apple/backend/RU billing и analytics.

Только этот модуль может подключать Adapty. Модели Adapty и StoreKit не выходят из
Infrastructure-слоя в Domain или UI.

### Entitlement Engine

Слои разделены так:

- Domain хранит чистые модели, три источника (`apple`, `primaryBackend`, `ruBilling`),
  freshness-policy, `AppleEntitlementVerifierProtocol`, только расширяемый каталог premium SKU
  и правила агрегации;
- Application-actor `EntitlementEngine` параллельно проверяет источники в рамках общего
  конечного deadline. `AppleEntitlementSourceFactory` создаёт одну регистрацию `.apple`;
- Data собирает общий `AppleEntitlementRepository` и типизированный
  `VersionedEntitlementCache`. Adapty и StoreKit считаются двумя проверяющими одного Apple-источника,
  поэтому в кеш попадает ровно одно утверждение для пары `apple + subject`;
- Infrastructure изолирует настоящие StoreKit transaction и Adapty profile. `AdaptyProfile`,
  `Transaction` и raw SDK errors не выходят в Domain, Data или UI;
- DI регистрирует один engine как `EntitlementRepositoryProtocol`,
  `RefreshEntitlementUseCaseProtocol` и минимальный `EntitlementStatusProviderProtocol` для AppFlow.

Итоговое правило:

- хотя бы один надёжный `active` даёт общий `active`;
- `inactive` можно вернуть, только если каждый настроенный источник явно подтвердил
  `inactive`;
- timeout, SDK/HTTP error, отсутствие авторизации и непроверенная transaction дают `unresolved`;
- для AppFlow `unresolved` преобразуется в `unknown` и не открывает premium.

Кеш имеет конечный TTL. После TTL ранее подтверждённый `active` может временно работать
внутри отдельного offline grace. `inactive` такого grace не получает. Subject бывает anonymous
или содержит непрозрачный 32-byte fingerprint. Поэтому raw user ID и email не попадают в ключ
хранилища. Ответ, пришедший после timeout, уже не может переписать кеш завершённой проверки.

### Переустановка и оплата

Удаление приложения стирает локальный кеш и pending-записи. Поэтому они не могут быть
источником подписки, токенов или RU-покупок. После восстановления app account
`RecoverCustomerAccessUseCase` запускает:

1. новую проверку entitlement;
2. сверку токенов с сервером;
3. загрузку RU-статуса.

Apple-покупки возвращают StoreKit и серверные источники. Токены и RU-покупки
возвращаются только по стабильному server customer. Подробнее: [восстановление после
переустановки](AccountRecovery.md).

### Каталог, paywall и entitlement Apple

StoreKit `currentEntitlements` проверяет точный bundle приложения, тип продукта и полный каталог
текущих и исторических premium SKU. Публичный клиент Adapty 3.17.3 помечает profile как
`unqualified`, потому что SDK не сообщает, пришёл ответ из сети или собственного кеша. Свежий
`active`/`inactive` через Adapty разрешён только при отдельно переданном server-validated client.

Production-адаптеры основного backend и RU Billing изолируют привязанную к пользователю
авторизацию, HTTPS transport и формат HTTP-данных. `AdaptyPaywallRepository` сохраняет каждый
продукт провайдера один в один: одинаковые SKU не объединяются, количество продуктов не
ограничивается.

`LoadPaywallUseCase` сначала загружает requested placement или его кеш, затем использует общий
резерв `.main` и его кеш. Purchase и restore запускают новую проверку entitlement. Только
подтверждённый `active` возвращает `.activated` или `.restored`. Если конфигурации special offer
нет, платформа не обращается к его placement, кешу, таймеру или UI. Если приложение не собрало
Entitlement Engine, безопасный `UnknownEntitlementStatusProvider` возвращает `unknown`.
Подробнее: [монетизация](Monetization.md) и [entitlement](Entitlements.md).

### Защита финансовых операций

Все Apple purchase, restore и RU checkout используют один `MonetizationOperationGate` на весь процесс.
Он не даёт запустить вторую оплату, пока первая остаётся неопределённой. Обрыв сети
даёт конечный `offline`/`timeout`, но не превращает неизвестный результат в ошибочное
повторное списание. Подробнее: [обрыв сети](NetworkInterruptions.md).

Постоянные Apple/RU pending-записи учитывают пользователя и доступны всему приложению. После
холодного запуска кешированный Adapty handle восстанавливается только при точном совпадении
variation, индекса, SKU и commercial fingerprint. Для расходуемой покупки нужен отдельный
app-owned fulfillment-слой: общий premium flow не начисляет токены.

Жизненный цикл показа paywall провайдера отделён от best-effort аналитики и передаётся в UI вместе
с `TrackPaywallEventUseCaseProtocol`. Возвращение сети само по себе не разрешает повторный
purchase, token charge, RU checkout или cancellation. Сначала приложение обязано выяснить
результат предыдущей операции.

## BroadUIFlows

`BroadUIFlows` содержит готовые SwiftUI-сценарии:

- loader;
- onboarding;
- адаптивный paywall;
- loading/error/retry-состояния;
- RU payment sheet и экран управления RU-подпиской.

View получает готовые зависимости через `init`. View не ищет сервисы в DI-контейнере и не
создаёт repository или use case.

### Общие loading/error/retry-экраны

`BroadLoadableView` обрабатывает все состояния `LoadableState`. При refresh и stale он может оставить
предыдущий контент. При блокирующей ошибке решение о показе предыдущего значения явно
принимает приложение. Готовые loader, refresh, empty, error и stale views получают app-owned
контент и `BroadLoadableTheme`. Они не создают `Task`, timeout, SDK или DI. Подробнее:
[общие UI-состояния](LoadableUI.md).

### AppFlow

AppFlow разделён на три части:

- `AppFlowStateMachine` без побочных эффектов выбирает `launch`, `onboarding`, `initialPaywall` или
  `main`;
- `KeyValueAppFlowProgressRepository` хранит монотонные маркеры onboarding/paywall, но не
  хранит entitlement;
- `AppFlowCoordinator` — `@MainActor`-объект, который управляет асинхронными переходами и
  защищается от поздних ответов. `BroadAppFlowView` только рисует текущий route.

Приложение запускает AppFlow только после bootstrap-состояния `ready` или `degraded`.
Подтверждённый `active` пропускает первичный paywall. `unknown` не превращается в `inactive`: бесплатный
main открывается, premium не выдаётся, checkpoint paywall не сохраняется. Поздний `inactive` не
выталкивает уже открытую сессию обратно на paywall. Если подтверждённый `active` пришёл во время
onboarding, AppFlow запоминает его для текущей сессии, но сначала даёт завершить onboarding.
Подробнее: [AppFlow](AppFlow.md).

### Onboarding и ATT

Onboarding получает стабильные ID слайдов, тексты и media от приложения. `OnboardingViewModel`
запускает ATT только когда:

1. первый слайд реально появился;
2. scene находится в `active`;
3. есть видимое window;
4. закончилась отменяемая задержка.

Нативный ATT SDK остаётся внутри Core-адаптера. Подробнее: [Onboarding и ATT](OnboardingAndATT.md).

## BroadExtensions

`BroadExtensions` — независимый набор часто нужных расширений:

- Hex Color;
- кастомные шрифты;
- закрытие клавиатуры по тапу мимо поля;
- возврат edge swipe-back.

Он не импортирует другие модули платформы. Приложение подключает `BroadExtensions` только
когда он нужен. [Готовые примеры →](Extensions.md).

## Точка сборки зависимостей

Приложение владеет composition root. Swinject-сборки подключаются в таком порядке:

1. `BroadCoreAssembly`;
2. `BroadMonetizationAssembly`;
3. `BroadUIFlowsAssembly`;
4. repository, use case и ViewModel конкретного приложения.

`BroadCoreAssembly` регистрирует descriptor модуля, bootstrap, cache, отдельный state store и logging.
Приложение может независимо передать готовый cache repository, `KeyValueStoreProtocol` для
постоянного состояния, logger и bootstrap-шаги или использовать изолированные UserDefaults и
`NoOpBroadLogger` по умолчанию. Если приложение само создаёт cache repository, оно само передаёт
в него тот же logger. `Resolver` и `Container` нельзя захватывать внутрь async-операции.

`BroadMonetizationAssembly(entitlementEngine:services:)` регистрирует готовый engine и опциональные
monetization services. Более низкоуровневый initializer позволяет отдельно передать
`EntitlementStatusProviderProtocol`; безопасный вариант по умолчанию возвращает `unknown`.
`BroadUIFlowsAssembly` регистрирует descriptor UI-модуля. Затем `@MainActor` composition root создаёт
`KeyValueAppFlowProgressRepository`, `AppFlowCoordinator`, onboarding/paywall ViewModel и root View.
View никогда не вызывает `resolve`.

Связанные гайды: [запуск](Bootstrap.md), [кеш и offline](CachingAndOffline.md),
[монетизация](Monetization.md), [entitlement](Entitlements.md), [логи](Logging.md),
[состояния UI](LoadableState.md), [AppFlow](AppFlow.md) и [ADR-0001](ADR/0001-module-boundaries.md).
