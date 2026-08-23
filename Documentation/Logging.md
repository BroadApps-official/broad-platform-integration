# Безопасное логирование в BroadCore

`BroadCore` пишет технические события так, чтобы по логам можно было восстановить
ход bootstrap, работу кеша и проверяемый статус приложения, но нельзя было
случайно отправить туда payload, секрет или персональные данные.

## Что входит в срез

| Тип | Ответственность |
|---|---|
| `BroadLoggerProtocol` | Единая синхронная и `Sendable`-граница для отправки события |
| `BroadLogEvent` | Закрытый список разрешённых typed-событий |
| `BroadLogLevel` | `debug`, `info`, `warning`, `error` |
| `BroadLogCategory` | Отдельные каналы для подсистем платформы |
| `OSLogBroadLogger` | Production-adapter поверх Unified Logging |
| `NoOpBroadLogger` | Безопасный logger по умолчанию, который ничего не записывает |

Новые события не принимают произвольную строку, metadata-словарь или raw
`Error`. Новое поле нельзя начать логировать случайно: сначала для него нужно
расширить публичную typed-модель и явно собрать безопасное сообщение в
единственном OSLog-adapter. Старый source-compatible case
`remoteFeatureFixtureEvaluated` ещё принимает строки, но OSLog-adapter намеренно
отбрасывает все его metadata; новый код использует только
`remoteFeatureFixtureResolved` с закрытыми enum, Bool и логическими placement.

## Категории

`BroadLoggerProtocol` отправляет технические события `bootstrap`, `cache` и
следующие статусы разработки/проверки:

| Тег | Typed-событие | Что разрешено |
|---|---|---|
| `[INPUT]` | `projectInputsRead` | Только четыре флага доступности источников |
| `[BACKEND]` | `backendMappingProgress` | Количество сопоставленных и всех функций |
| `[FLOW]` | `flowAdvanced` | Переход между закрытыми `BroadLogFlowStage` |
| `[TOKENS]` | `tokenBalanceConfirmed` | Сам факт подтверждения баланса backend |
| `[ANALYTICS]` | `analyticsEventsRecorded` | Количество записанных typed-событий |
| `[UI]` | `uiVisualReviewRemaining` | Число экранов, требующих сверки |
| `[BLOCKED]` | `workBlocked` | Закрытые capability и причина блокера |
| `[PASS]` | `verificationPassed` | `functional`, `visual` или `full` |

Категории `networking`, `monetization`, `paywall`, `purchase`, `ruBilling` и
`experiments` зарезервированы, но не принимают произвольные строки.
Monetization lifecycle проходит через отдельный typed
`MonetizationAnalyticsProtocol`, где также нет raw payload/PII.

`[EXPERIMENTS] remote-feature.fixture.resolved` хранит только закрытый fixture
scenario, итог resolution, логические `main`/`special-offer`/`tokens`/`other`,
флаг наличия variation и закрытый provenance. Сам variation ID и provider
placement в Console не попадают.

## Подключение

Production-приложение создаёт один logger в composition root и передаёт тот же экземпляр всем компонентам:

```swift
let logger = OSLogBroadLogger(
    subsystem: "com.example.app"
)

let cacheRepository = VersionedJSONCacheRepository(
    keyValueStore: UserDefaultsKeyValueStore(
        namespace: "com.example.app.cache"
    ),
    logger: logger
)

let coreAssembly = BroadCoreAssembly(
    bootstrapSteps: bootstrapSteps,
    cacheRepository: cacheRepository,
    logger: logger
)

logger.log(
    .backendMappingProgress(mapped: 8, total: 9)
)
logger.log(
    .workBlocked(capability: .history, reason: .backendContractMissing)
)
```

`subsystem` принимает только `StaticString`, поэтому его нужно задать строковым литералом. Используйте постоянный bundle-style идентификатор приложения; runtime-значение пользователя, email, user ID или токен передать в этот API нельзя.

Если приложение передаёт собственный `CacheRepositoryProtocol`, `BroadCoreAssembly` не может пересобрать его и внедрить logger автоматически. В таком случае logger нужно передать repository при его создании, как в примере выше. Встроенный repository получает logger автоматически.

Для preview, вспомогательного процесса или приложения без логирования можно ничего не передавать: `NoOpBroadLogger` уже является значением по умолчанию.

`BroadAppTemplate` передаёт тот же logger в analytics recorder, token balance
callback и app flow. Поэтому Console показывает только подтверждённые факты:
число принятых analytics events, подтверждение backend token balance и реальный
переход из initial paywall в special offer или main.

## Понятный результат остаётся в интерфейсе

Console не заменяет результат для разработчика. Build/check agent показывает в
чате или в экране Debug Status короткий отчёт с теми же тегами. Допустимый
пример:

```text
[INPUT] Источники проекта прочитаны
[BACKEND] 8/9 функций сопоставлены
[FLOW] initial paywall → special offer
[TOKENS] Backend подтвердил баланс
[ANALYTICS] Записано 5 событий
[UI] Требуется визуальная сверка 2 экранов
[BLOCKED] Для функции history отсутствует endpoint
[PASS] Функциональная проверка завершена
```

В Console эти сообщения представлены безопасными typed-полями, например
`[BACKEND] backend.mapping.progress mapped=8 total=9`. Текст функции, endpoint,
payload и причины из SDK туда не переносятся. Детали блокера остаются в
пользовательском отчёте и не должны содержать секреты.

## Что записывается

- начало, присоединение, retry, отмена и итоговое состояние bootstrap;
- количество critical/background шагов;
- индекс и тип шага, число попыток и безопасный `AppError.Kind`;
- `fresh`, `stale` или typed-причина отсутствия cache entry;
- успех или безопасный класс ошибки операций `read/write/remove/cleanup`.
- доступность четырёх источников, числовой прогресс backend/UI и переход flow;
- факт подтверждения token balance и число безопасных analytics events;
- закрытая причина блокера и scope действительно завершённой проверки.

Индекс шага безопасно связывает события внутри одного запуска. Имя и ID шага намеренно не записываются: host app может случайно положить в них приватное значение.

Итог шага логируется только после завершения timeout-race. Если SDK проигнорировал cancellation и ответил позже timeout, ложного события `completed` не появится.

## Что никогда не записывается

- cache payload, `Data`, physical cache key, schema ID и namespace;
- user-facing текст ошибки, raw SDK `Error`, `localizedDescription` и diagnostic details;
- payment URL, bearer/API key, receipt, email и полный user ID;
- raw provider placement ID, product ID, SKU, variation ID или remote-config value;
- произвольные строки и произвольные metadata-словари;
- названия backend endpoint, request/response payload и текст UI-сверки.

Все сформированные OSLog-поля имеют privacy `.public`, потому что они получены
только из закрытых enum, Bool и числовых счётчиков. Добавлять в этот adapter
входную строку из SDK, backend или host app запрещено. Metadata legacy fixture-
события заменяются маркером `legacy_metadata=discarded` и не интерполируются.

Если приложение прикладывает отдельный файл диагностики к письму в поддержку,
для него действуют те же ограничения. Формат письма и checklist очистки файла
описаны в [Support Email](SupportEmail.md).

## Свой logger

Приложение может реализовать `BroadLoggerProtocol`, например для отправки разрешённых событий в свою observability-систему:

```swift
struct AppLogger: BroadLoggerProtocol {
    func log(_ event: BroadLogEvent) {
        // Exhaustive mapping только из typed event в заранее разрешённую схему.
    }
}
```

Реализация должна быть потокобезопасной, быстрой и неблокирующей. Нельзя выполнять синхронный network/disk I/O, повторно входить в bootstrap/cache или превращать событие в строку через reflection. Если события буферизуются, очередь должна быть ограниченной, чтобы logging не создал бесконечный рост памяти.

## Автоматические ограничения

`./Scripts/lint.sh` дополнительно проверяет, что:

- в production-коде нет `print`, `debugPrint`, `dump`, `NSLog` и записи в stdout/stderr;
- legacy `os_log` и signposter API не используются;
- `OSLog` импортируется только в `OSLogBroadLogger.swift`;
- raw error description не превращается в лог;

## Ручная проверка

Запустите `BroadAppTemplate` в Simulator с нужным launch argument, затем откройте macOS Console и отфильтруйте по subsystem:

```text
com.broadapps.platform.template
```

Полезные сценарии:

- `-bootstrap-seed-cache`: появляется успешный `cache.operation.completed operation=write`;
- `-bootstrap-stale-cache`: появляются `cache.read.completed result=stale`, timeout/degraded bootstrap и при повторном запуске stale-снапшот остаётся доступен;
- `-bootstrap-degraded`: фоновый timeout переводит готовое приложение в `degraded`;
- `-bootstrap-failed-once`: первый critical run заканчивается `failed`, ручной retry — `ready`.
- открытие special offer после initial paywall: `[FLOW] ... to=special-offer`;
- подтверждённое зачисление token fixture: `[TOKENS] tokens.balance.confirmed`;
- любое monetization fixture-событие: `[ANALYTICS] ... count=<N>`.

Проверьте, что в Console отсутствуют cache payload, пользовательские сообщения об ошибках, suite/namespace и физические cache keys.

В проекте намеренно нет test targets: эти launch-сценарии являются ручными acceptance fixtures.
