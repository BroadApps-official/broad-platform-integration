# Запуск SDK и кеширование контента

Это практическая инструкция для composition root нового
приложения. Она отвечает на три вопроса:

1. что нужно создать сразу при запуске;
2. какие SDK разрешено ждать на loader;
3. как показать последний безопасный контент, если сеть пропала.

> [!IMPORTANT]
> Swift Package и CocoaPods-библиотеки не «скачиваются» при каждом
> запуске — они уже входят в сборку. В startup мы инициализируем
> конкретные сервисы: восстанавливаем сессию, запускаем listener,
> активируем нужный SDK и загружаем данные.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="Assets/README/startup-cache-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="Assets/README/startup-cache-light.svg">
  <img alt="Порядок запуска критических и фоновых SDK, чтения кеша и offline fallback" src="Assets/README/startup-cache-light.svg" width="100%">
</picture>

## Короткое правило

| Вопрос | Куда отнести операцию |
|---|---|
| Без результата нельзя безопасно выбрать первый экран? | `critical`: выполнить по очереди с конечным timeout |
| Результат полезен, но первый экран без него безопасен? | `background`: запустить после открытия UI |
| Сервис нужен только в отдельной функции? | Lazy / on demand: создать адаптер заранее, вызвать при входе в функцию |
| Операция показывает permission, чат, review или payment UI? | Только после явного UI-события, никогда на loader |

## Эталонный порядок запуска

### 1. Синхронно собрать зависимости

В `AppCompositionRoot` создаются и живут весь нужный им срок:

- app configuration и безопасные локализованные ошибки;
- logger;
- один постоянный `CacheRepositoryProtocol`;
- один `MonetizationOperationGate`;
- стабильный `EntitlementSubject` для текущего app-account;
- SDK/HTTP/storage adapters и use cases;
- `BootstrapStep` и ViewModel.

Сама сборка объектов не делает сетевых запросов и не показывает
системные окна.

### 2. До активации монетизации запустить StoreKit listener

В production до первого `services.activate()` должен быть создан один
долгоживущий listener `Transaction.updates`. Он не ждёт первую
транзакцию на loader, а только подписывается на будущие verified updates.
Полный bridge показан в [Getting Started](GettingStarted.md#storekit-updates-и-recovery).

### 3. Выполнить `critical` шаги по очереди

Примеры: миграция локальной схемы, восстановление сессии, получение
обязательной конфигурации или свежая проверка доступа, если от неё
зависит первый route.

Каждый шаг имеет уникальный ID, конечный timeout и явную retry-policy.
Повторный `start()` присоединяется к тому же запуску и не активирует
SDK второй раз.

### 4. Открыть UI

- `ready` — критические шаги завершены;
- `degraded` — безопасный UI можно открыть, но часть данных взята из
  fallback или фоновый сервис недоступен;
- `failed` — безопасного route нет; показываем ошибку и `Retry`.

### 5. Запустить `background` шаги параллельно

Сюда обычно относятся telemetry, прогрев некритичного SDK и другие
опциональные сервисы. Их ошибка может сделать состояние `degraded`,
но не закрывает уже открытый экран.

## Куда отнести конкретные сервисы

| Сервис | Как запускать |
|---|---|
| Восстановление app-account/session | `critical`, если без account нельзя выбрать route или subject |
| Свежая проверка entitlement | `critical` только когда первый route зависит от premium; timeout/offline → `unresolved` |
| Adapty | Активировать через готовый activation gate. `critical` только при реальной зависимости route; иначе background/lazy |
| StoreKit `Transaction.updates` | Один process-lifetime listener до `services.activate()`; не блокирует loader |
| Analytics/telemetry | `background`; его ошибка не должна делать app нерабочим |
| RU Billing | Собирать только если feature настроен; на startup не открывать checkout и не начинать payment |
| Usedesk | Lazy: инициализировать/открыть по тапу `Настройки → Онлайн-чат` |
| ATT | Только после фактического появления первого onboarding-слайда |
| Rate Us | По отдельному событию вне onboarding; не на loader |

### Готовый шаг активации SDK

Этот код показывает точную границу. Приложение само выбирает
`.critical` или `.background` по таблице выше:

```swift
func makeMonetizationActivationStep(
    activate: any ActivateMonetizationUseCaseProtocol,
    criticality: BootstrapCriticality
) -> BootstrapStep {
    BootstrapStep(
        id: BootstrapStepID(rawValue: "monetization-activation"),
        name: "Активация монетизации",
        criticality: criticality,
        timeoutPolicy: .seconds(3),
        retryPolicy: .none
    ) {
        switch await activate() {
        case .activated:
            return .completed
        case let .unavailable(error):
            throw error
        }
    }
}
```

Adapty дополнительно защищён общим activation gate: одновременные
paywall/restore/entitlement-запросы не создадут несколько activation для одной
composition.

## Кеширование контента

### Что даёт платформа

| Готовый тип | Зачем |
|---|---|
| `VersionedJSONCacheRepository` | Общий typed JSON-cache: schema ID, version, TTL, fresh/stale/missing и atomic operations |
| `UserDefaultsKeyValueStore` | Постоянное хранение небольших снапшотов; лимит одной записи 512 KiB по умолчанию |
| `VersionedPaywallCache` | Готовый paywall-cache: отдельный subject + placement, TTL и предельный stale-age |
| `CachedRUCatalogRepository` | Remote-first RU-каталог с subject-scoped offline fallback |
| `CachedStorefrontRepository` | Свежая StoreKit storefront и безопасная локальная подсказка |
| `VersionedEntitlementCache` | Ограниченный по времени cache проверок access; `unresolved` не записывается |

### Что можно и нельзя класть в общий cache

| Можно | Нельзя |
|---|---|
| Небольшой remote config | API bearer, backend credential и секретный token |
| Provider-neutral paywall payload | Raw SDK object, receipt/JWS и payment URL |
| Небольшой каталог или metadata | Единственное доказательство premium или token balance |
| Прогресс и безопасное UI-состояние | Изображение, видео или большой каталог в `UserDefaults` |
| Subject-scoped entitlement assertion через готовый engine | Email, raw user ID или SDK profile ID в key/payload/log |

> [!WARNING]
> Кеш может оставить на экране последний каталог, но не может сам
> открыть premium, начислить токены или подтвердить RU-оплату.

### Порядок загрузки контента

1. Показать `loading(previousValue:)`, если на экране уже есть контент.
2. Прочитать typed cache.
3. Сделать remote-запрос с конечным timeout.
4. При валидном ответе показать `.loaded` и записать новый envelope.
5. При offline/timeout и разрешённом fallback показать `.stale(value:error:)`.
6. Если пригодного cache нет, показать `.error` и кнопку `Retry`.

Сетевая ошибка не удаляет предыдущий валидный snapshot. Новое
значение записывается только после успешного decoding и доменной
валидации.

### Готовый постоянный paywall-cache

```swift
let platformStore = UserDefaultsKeyValueStore(
    namespace: "com.example.my-app.platform"
)
let platformCache: any CacheRepositoryProtocol = VersionedJSONCacheRepository(
    keyValueStore: platformStore,
    logger: appLogger
)

let paywallCacheError = AppError(
    kind: .unavailable,
    userMessage: "Не удалось открыть сохранённые тарифы.",
    diagnosticCode: "paywall.cache.unavailable",
    isRetryable: true
)
let appPaywallCache = VersionedPaywallCache(
    repository: platformCache,
    subject: entitlementSubject,
    freshTimeToLive: 15 * 60,
    maximumStaleAge: 24 * 60 * 60,
    unavailableError: paywallCacheError
)

let services = factory.makeServices(
    entitlementRepository: entitlementEngine,
    analytics: analytics,
    paywallCache: appPaywallCache,
    errors: safeFlowErrors,
    pendingApplePurchaseStore: pendingAppleStore,
    pendingAppleTransactionRecovery: transactionRecovery,
    operationGate: operationGate
)
```

`VersionedPaywallCache`:

- не смешивает paywall разных `EntitlementSubject`;
- хранит каждый placement отдельно;
- не возвращает пустой, чужой или слишком старый payload;
- создаёт новые presentation IDs перед повторным показом через `LoadPaywallUseCase`;
- не хранит raw Adapty object;
- не даёт право на purchase: перед списанием SDK-product повторно
  загружается и сверяется по variation, index, SKU и commercial fingerprint.

При login/logout создайте новую subject-bound monetization composition и
`VersionedPaywallCache` поверх того же app-wide `platformCache`.

## Что увидит пользователь

| Ситуация | UI |
|---|---|
| Первый запуск, cache ещё нет | Loader с конечным ожиданием; затем content или error/retry |
| Повторный запуск, cache есть | Последний безопасный content может остаться на экране во время refresh |
| Сеть пропала, cache пригоден | Stale-content + понятный offline/banner + ручной Retry |
| Сеть пропала, cache нет, повреждён или слишком стар | Error + Retry; не показываем выдуманный content |
| Интернет исчез во время purchase/RU/token write | Статус `pending/unresolved`; только reconciliation, без автоматического повтора списания |

## Проверка перед передачей

- [ ] У каждого startup-шага есть ID, criticality, timeout и retry-policy.
- [ ] Критические шаги запускаются по очереди; фоновые — после UI и параллельно.
- [ ] StoreKit updates listener создан один раз до активации monetization.
- [ ] ATT, Rate Us, Usedesk, purchase и restore не запускаются на loader.
- [ ] Каждый cache key имеет стабильные name/schema/version и конечный TTL.
- [ ] Для stale-контента задан предельный возраст, а не бессрочный fallback.
- [ ] Offline/timeout не удаляет валидный snapshot и не превращает `unresolved` в `inactive`.
- [ ] Кеш не является единственным доказательством premium, token balance или RU-оплаты.
- [ ] Login/logout пересоздаёт subject-bound cache/repositories, но не создаёт второй app-wide financial gate.

Детальные контракты: [Bootstrap](Bootstrap.md),
[Caching & Offline](CachingAndOffline.md), [Loadable State](LoadableState.md),
[Network Interruptions](NetworkInterruptions.md) и [Entitlements](Entitlements.md).
