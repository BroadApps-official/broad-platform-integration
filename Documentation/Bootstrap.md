# Запуск приложения

`BroadCore` содержит один предсказуемый механизм запуска. Он выполняет шаги,
которые передало приложение, и не импортирует SwiftUI, Adapty, StoreKit или типы
конкретного приложения.

Если вы впервые собираете composition root, начните с практической инструкции
[«Запуск SDK и кеш»](StartupAndCaching.md). Здесь ниже находится полный контракт
bootstrap engine и объяснение его граничных состояний.

## Состояния запуска

```text
idle → starting ─┬→ ready
                 ├→ degraded
                 └→ failed(error) → retry → starting
```

- `ready` — все критические шаги успешно завершились;
- `degraded` — приложение может работать, но критический шаг использовал безопасный
  fallback или фоновый шаг закончился ошибкой/timeout уже после открытия экрана;
- `failed` — критический шаг исчерпал все попытки и время, а безопасного fallback нет;
- повторный `start()` присоединяется к уже идущему запуску и не активирует SDK второй раз;
- `retry()` начинает новую generation только из `failed`. Поздние ответы старой generation игнорируются.

## Что такое `BootstrapStep`

Каждый `BootstrapStep` имеет:

- уникальный `BootstrapStepID`;
- имя;
- признак критичности;
- `TimeoutPolicy`;
- `RetryPolicy`;
- `@Sendable` async-операцию.

### Критические шаги

Они выполняются по очереди, в том порядке, в котором их передало приложение.
Делайте шаг критическим только тогда, когда без него нельзя безопасно выбрать и показать
первый экран.

- `.completed` — шаг закончился, идём дальше;
- `.degraded(AppError)` — шаг осознанно использовал валидный fallback или кеш; повторять его не нужно;
- брошенная ошибка обрабатывается по `RetryPolicy`; если попытки закончились, состояние становится
  `.failed`.

### Фоновые шаги

Они начинаются после того, как критическая часть вернула `ready` или `degraded`.
Фоновые шаги выполняются параллельно и никогда не держат loader. Их ошибка может изменить
`ready` на `degraded`, но не на `failed`.

## Как работает timeout

`TimeoutPolicy.limit` — общее время одного шага. В него уже входят все попытки и задержки
между ними. Бесконечного timeout нет.

Если время вышло, координатор сразу прекращает ждать и игнорирует поздний ответ. Если SDK
игнорирует cancellation, следующая попытка присоединяется к ещё идущему вызову, а не создаёт
дубль. Swift не может насильно остановить такой SDK-вызов. Поэтому неидемпотентная активация
обычно использует `RetryPolicy.none` и дополнительную защиту внутри адаптера.

## Как работают повторы

`RetryPolicy.delays` хранит задержку перед каждым повтором. Общее количество попыток равно
`delays.count + 1`.

```swift
let noRetry = RetryPolicy.none
let fixed = RetryPolicy.fixed(retryCount: 2, delay: 0.3)
let backoff = RetryPolicy.exponential(
    retryCount: 3,
    initialDelay: 0.2,
    multiplier: 2,
    maximumDelay: 1.5
)
```

Повторяются только ошибки `AppError` с `isRetryable == true`. Неизвестная ошибка сначала
очищается от небезопасных данных и не повторяется, пока адаптер её не классифицирует.
`CancellationError` управляет потоком выполнения и не показывается как ошибка пользователю.

## Безопасные ошибки

`AppError` хранит только:

- тип ошибки;
- безопасное сообщение для пользователя;
- очищенный diagnostic code;
- признак возможности повтора.

Raw SDK errors, payment URL, access token, API key и полный ID пользователя не выходят в публичный
контракт. Тексты для timeout и unknown error передаёт само приложение через
`BootstrapErrorMessages`. Поэтому локализация и тон текста не зашиты в `BroadCore`.

## Логирование

Координатор передаёт в `BroadLoggerProtocol` только закрытые `BroadLogEvent`. Он логирует этап
жизненного цикла, переход состояния, тип/индекс шага, номер попытки и безопасный
`AppError.Kind`.

В лог не попадают `BootstrapStepID`, имя шага, текст для пользователя, diagnostic code и raw error.
Событие о завершении шага пишется только после завершения timeout-race. Поздний ответ SDK не
создаст ложный success. Подробнее: [логирование](Logging.md).

## Как состояние запуска попадает в UI

`AppBootstrapState` остаётся контрактом engine и хранит `ready/degraded/failed`. Example ViewModel
хранит контент модулей в `LoadableState<[ModuleItem]>`:

- `ready` и `degraded` дают `loaded`-контент;
- отдельное render-состояние показывает, что bootstrap находится в `degraded`;
- `failed` преобразуется в `error`.

Не превращайте каждый bootstrap `degraded` в content `stale`. Timeout фонового SDK не делает
остальной контент устаревшим. `LoadableState.stale` создаёт только feature-результат, который явно
разрешает использовать кеш. Подробнее: [состояния UI](LoadableState.md).

## Сборка зависимостей

Сначала синхронно получите конкретные зависимости, затем создайте шаги и передайте их
в `BroadCoreAssembly`.

```swift
let steps: [BootstrapStep] = [
    makeLocalConfigurationStep(configurationStore),
    makeRequiredServicesStep(serviceAdapter),
    makeOptionalTelemetryStep(telemetryAdapter)
]

let assembler = Assembler([
    BroadCoreAssembly(bootstrapSteps: steps)
])
```

Не захватывайте Swinject `Resolver` или `Container` внутрь шага. Они нужны только в composition root,
а не внутри async-операции.

## Где запрашивать ATT

ATT нельзя добавлять в bootstrap. ATT-запрос живёт в отдельном адаптере и вызывается только
после того, как первый onboarding-слайд реально появился на экране.

## Готовые сценарии example-приложения

`BroadAppTemplate` содержит детерминированные фиктивные шаги без живых SDK:

- без аргумента: `idle → starting → ready`;
- `-bootstrap-degraded`: фоновая операция игнорирует cancellation, timeout освобождает
  координатор, UI остаётся доступным в `degraded`;
- `-bootstrap-failed-once`: первый критический запуск падает, нажатие «Повторить» доводит его до
  `ready`;
- `-bootstrap-seed-cache`: записывает снимок конфигурации с TTL `0` и возвращает `ready`;
- `-bootstrap-stale-cache`: в новом процессе читает этот снимок, имитирует network timeout и даёт
  `degraded`, не удаляя stale-значение.

Тестовых target в package нет. Эти сценарии запускаются вручную как acceptance fixtures.
Сценарии с кешем нужно запускать в двух разных процессах. Точный порядок: [кеш и
offline](CachingAndOffline.md).
