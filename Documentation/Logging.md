# Безопасное логирование в BroadCore

`BroadCore` пишет технические события так, чтобы по логам можно было восстановить ход bootstrap и работу кеша, но нельзя было случайно отправить туда payload, секрет или персональные данные.

## Что входит в срез

| Тип | Ответственность |
|---|---|
| `BroadLoggerProtocol` | Единая синхронная и `Sendable`-граница для отправки события |
| `BroadLogEvent` | Закрытый список разрешённых typed-событий |
| `BroadLogLevel` | `debug`, `info`, `warning`, `error` |
| `BroadLogCategory` | Отдельные каналы для подсистем платформы |
| `OSLogBroadLogger` | Production-adapter поверх Unified Logging |
| `NoOpBroadLogger` | Безопасный logger по умолчанию, который ничего не записывает |

Logger не принимает произвольную строку, metadata-словарь или raw `Error`. Новое поле нельзя начать логировать случайно: сначала для него нужно расширить публичную typed-модель и явно собрать безопасное сообщение в единственном OSLog-adapter.

## Категории

`BroadLoggerProtocol` сейчас отправляет технические события `bootstrap` и `cache`. Категории `networking`, `monetization`, `paywall`, `purchase`, `ruBilling` и `experiments` зарезервированы, но не принимают произвольные строки. Monetization lifecycle проходит через отдельный typed `MonetizationAnalyticsProtocol`, где также нет raw payload/PII.

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
```

`subsystem` принимает только `StaticString`, поэтому его нужно задать строковым литералом. Используйте постоянный bundle-style идентификатор приложения; runtime-значение пользователя, email, user ID или токен передать в этот API нельзя.

Если приложение передаёт собственный `CacheRepositoryProtocol`, `BroadCoreAssembly` не может пересобрать его и внедрить logger автоматически. В таком случае logger нужно передать repository при его создании, как в примере выше. Встроенный repository получает logger автоматически.

Для preview, вспомогательного процесса или приложения без логирования можно ничего не передавать: `NoOpBroadLogger` уже является значением по умолчанию.

## Что записывается

- начало, присоединение, retry, отмена и итоговое состояние bootstrap;
- количество critical/background шагов;
- индекс и тип шага, число попыток и безопасный `AppError.Kind`;
- `fresh`, `stale` или typed-причина отсутствия cache entry;
- успех или безопасный класс ошибки операций `read/write/remove/cleanup`.

Индекс шага безопасно связывает события внутри одного запуска. Имя и ID шага намеренно не записываются: host app может случайно положить в них приватное значение.

Итог шага логируется только после завершения timeout-race. Если SDK проигнорировал cancellation и ответил позже timeout, ложного события `completed` не появится.

## Что никогда не записывается

- cache payload, `Data`, physical cache key, schema ID и namespace;
- user-facing текст ошибки, raw SDK `Error`, `localizedDescription` и diagnostic details;
- payment URL, bearer/API key, receipt, email и полный user ID;
- placement ID, product ID, SKU или remote-config value до появления отдельной typed privacy-модели;
- произвольные строки и произвольные metadata-словари.

Все сформированные OSLog-поля имеют privacy `.public`, потому что они получены только из закрытых enum и числовых счётчиков. Добавлять в этот adapter входную строку из SDK, backend или host app запрещено.

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

Проверьте, что в Console отсутствуют cache payload, пользовательские сообщения об ошибках, suite/namespace и физические cache keys.

В проекте намеренно нет test targets: эти launch-сценарии являются ручными acceptance fixtures.
