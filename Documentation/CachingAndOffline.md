# Cache и offline в BroadCore

`BroadCore` хранит небольшие локальные снапшоты так, чтобы приложение могло быстро открыть рабочий экран без сети. Кеш не подменяет сервер: он даёт последнее известное значение и явно сообщает, свежее оно или устаревшее. Допустим ли stale-значение как fallback, решает доменный feature, а не общий cache-слой.

Удаление приложения удаляет этот cache целиком. Купленная подписка, token balance
и RU entitlement не могут храниться только здесь: после новой установки они
восстанавливаются через StoreKit/server account recovery. Локальный cache лишь
ускоряет offline UX. [Account Recovery →](AccountRecovery.md).

Если сеть исчезла во время запроса, adapter обязан закончить его конечным
typed offline/timeout результатом. Cache не разрешает автоматически повторять
финансовый write; такой flow сохраняет pending и сначала делает reconciliation.
[Network Interruptions →](NetworkInterruptions.md).

## Два разных paywall cache

| Источник | Кто им управляет | Обычный paywall | `special_offer` | `ru_pay` |
|---|---|---:|---:|---:|
| Adapty provider cache | Adapty SDK внутри текущего запроса | да | да | нет |
| Platform cache | `VersionedPaywallCache` BroadMonetization | да | нет | нет |

Adapty не раскрывает через public SDK, пришёл ли текущий payload из сети или его
managed cache, поэтому provenance называется `.providerCacheFallbackPossible`.
Это текущий ответ provider-а. Platform cache — сохранённая самим приложением
копия: при чтении `LoadPaywallUseCase` обязательно понижает её provenance до
`.platformCache` и удаляет обе capability. RU Billing отдельно требует
`.verifiedFreshRemote`, которого provider cache не даёт.

Прошлые `special_offer = true` и `ru_pay = true` никогда не переносятся в новый
absent/false/invalid payload. При offline platform cache помогает отрисовать
тарифы, но не включает удалённую кампанию и RU methods.

## Что входит в слой

| Тип | Ответственность |
|---|---|
| `CacheKey<Value>` | Связывает стабильные name/schema ID, тип payload, версию схемы и TTL-policy |
| `CacheEnvelope<Value>` | Хранит payload, `schemaIdentifier`, `version`, `savedAt` и `expiresAt` |
| `CacheRepositoryProtocol` | Даёт typed `read/write/remove` и atomic `insertIfMissing/replace/remove(ifMatching:)` |
| `VersionedJSONCacheRepository` | Кодирует envelope в JSON и определяет `fresh`, `stale` или причину отсутствия |
| `KeyValueStoreProtocol` | Изолирует storage и предоставляет snapshot-based conditional write/remove |
| `UserDefaultsKeyValueStore` | Actor-adapter для небольших флагов и снапшотов |
| `CacheClock` | Передаваемая граница времени; production использует `.system` |
| `VersionedPaywallCache` | Subject- и placement-scoped адаптер для offline paywall с конечным stale-age |

`Domain` и вызывающий код не обращаются к `UserDefaults`, `JSONEncoder` или файловой системе напрямую.

## Три результата чтения

```swift
switch try await cacheRepository.read(configurationKey) {
case let .fresh(envelope):
    apply(envelope.value)

case let .stale(envelope):
    apply(envelope.value)
    showOfflineState()

case let .missing(reason):
    showUnavailableState(reason)
}
```

- `fresh` — версия совпала, payload читается, `savedAt <= now < expiresAt`.
- `stale` — TTL закончился или системные часы оказались раньше `savedAt`. Значение остаётся доступным.
- `missing(.notFound)` — записи нет.
- `missing(.corrupted)` — запись имеет неверный тип, слишком велика или не декодируется.
- `missing(.schemaMismatch)` — storage entry помечен другим стабильным schema ID; по умолчанию он сохраняется.
- `missing(.versionMismatch)` — сохранённая и ожидаемая версии схемы различаются.

Paywall/storefront payloads повторно валидируют nested identifiers, money,
subscription periods, product fingerprints, fallback origin и даты именно в
`init(from:)`. Synthesized decoding не может обойти validating initializer и
оставить значение, которое позже упадёт на `precondition`.

Граница TTL точная: при `now == expiresAt` запись уже `stale`.

`CacheReadResult` описывает состояние записи в storage, а не готовое состояние экрана. Feature решает, допустим ли stale payload: разрешённый fallback маппится в `LoadableState.stale`, недопустимый — в `LoadableState.error`. Общий cache-слой не принимает это продуктовое решение. Подробная таблица: [Loadable state](LoadableState.md).

## Подключение

Для небольшого JSON-снапшота:

```swift
struct CachedConfiguration: Codable, Sendable {
    let isFeatureEnabled: Bool
}

let store = UserDefaultsKeyValueStore(
    namespace: "com.example.app.cache"
)
let logger = OSLogBroadLogger(
    subsystem: "com.example.app"
)
let cacheRepository: any CacheRepositoryProtocol = VersionedJSONCacheRepository(
    keyValueStore: store,
    logger: logger
)
let key = CacheKey<CachedConfiguration>(
    name: "remote-configuration",
    schemaIdentifier: "com.example.remote-configuration",
    version: 1,
    policy: CachePolicy(timeToLive: 60 * 60)
)

let coreAssembly = BroadCoreAssembly(
    bootstrapSteps: bootstrapSteps,
    cacheRepository: cacheRepository,
    logger: logger
)
```

Если host не передал repository, `BroadCoreAssembly` создаёт container-scoped реализацию на базе `UserDefaultsKeyValueStore` с namespace `com.broadapps.platform.cache`.

Для paywall не нужно писать свой `PaywallCacheProtocol`. Готовый
`VersionedPaywallCache` использует тот же repository, но добавляет
доменные границы: отдельный cache для subject/placement, запрет на пустой
или чужой payload и конечный `maximumStaleAge`. Готовый composition-пример:
[запуск SDK и кеш](StartupAndCaching.md#готовый-постоянный-paywall-cache).

## Логирование кеша

Repository отправляет через `BroadLoggerProtocol` только результат `fresh/stale/missing`, тип операции и безопасный класс ошибки. Payload, `Data`, key name, schema ID, namespace, suite и raw storage/encoding error не логируются. Сетевой слой позднее получит отдельные typed-события и не будет расширять cache event произвольными строками.

Если host создаёт свой repository, тот же logger нужно передать ему явно до сборки `BroadCoreAssembly`. Подробный контракт: [Logging](Logging.md).

## Правило offline fallback

Сетевой timeout, отсутствие соединения и временная ошибка сервера не удаляют кеш. Сетевой repository действует в таком порядке:

1. Читает локальный typed cache.
2. Пытается получить данные из сети с timeout.
3. При успешном валидном ответе записывает новый envelope.
4. При сетевой ошибке возвращает сохранённый `fresh` или `stale` payload и переводит feature/app в `degraded` или `unresolved`.
5. Удаляет значение только по явному продуктово-доменному правилу, а не из-за сетевой ошибки.

Для entitlement это особенно важно: timeout означает `unresolved`, а не `inactive`. Готовый `EntitlementEngine` записывает новый assertion только после явного валидного `active` или `inactive`; поздний ответ после общего deadline не пишет cache от имени завершённого refresh.

Для paywall порядок уже реализован в `LoadPaywallUseCase`: remote requested
placement → его fresh/stale cache → remote `main` → cache `main`. Кешированный
payload можно показать, но перед purchase платформа обязательно повторно
загружает provider-product и сверяет его точные commercial-условия.

## Entitlement-cache поверх BroadCore

`VersionedEntitlementCache` находится в `BroadMonetization`, но использует общий `CacheRepositoryProtocol`. Он добавляет доменные правила, которых нет у универсального cache-слоя:

- отдельная запись для каждого логического source: `apple`, `primaryBackend`, `ruBilling`;
- отдельный scope для `.anonymous` или непрозрачного 32-byte fingerprint пользователя;
- собственные `validatedAt`, `freshUntil` и `activeGraceUntil`;
- конечный TTL для `active` и `inactive`;
- дополнительный конечный offline grace только для прежнего `active`;
- ограничение grace настоящим `expiresAt`, если источник его знает;
- полный запрет на запись `unresolved`.

Внешний `CacheEnvelope` может физически храниться дольше доменного TTL. Это не продлевает entitlement: при каждом чтении `EntitlementAggregator` повторно ограничивает запись текущей source-policy.

После TTL cached `inactive` становится `unresolved`. Cached `active` остаётся пригодным только до active grace deadline; после него тоже становится `unresolved`. `.unspecified` не означает lifetime и подчиняется тем же конечным границам.

Raw user ID, email и SDK profile ID в storage не передаются. Host вычисляет непрозрачный fingerprint до создания `EntitlementSubject`; кеш принимает ровно 32 байта. Полная таблица агрегации и подключение: [Entitlements](Entitlements.md).

## Версии и миграции

Физическая identity записи состоит из стабильных `namespace + schemaIdentifier + name`. Store и repository кодируют UTF-8 длину каждого составного префикса в physical key, чтобы разные пары не могли склеиться в одинаковую строку. Один schema ID должен всегда означать одну логическую схему payload. Это не даёт двум feature с одинаковым `name` случайно удалить данные друг друга.

Версия хранится внутри envelope и не добавляется к storage key. Поэтому новый код видит фактическую старую версию и не создаёт молча второй независимый ключ. Minimal identity-header читает `version` до full payload, поэтому старая metadata-схема не маскирует version mismatch под corruption.

По умолчанию corrupted и version-mismatched записи удаляются. Если данные нужно мигрировать, временно задайте `versionMismatchAction: .preserve`, прочитайте тот же storage key через typed legacy-key старой версии, преобразуйте payload и только после успешного кодирования запишите новую версию.

```swift
let newKey = CacheKey<NewPayload>(
    name: "remote-configuration",
    schemaIdentifier: "com.example.remote-configuration",
    version: 2,
    policy: CachePolicy(
        timeToLive: 3_600,
        versionMismatchAction: .preserve
    )
)
```

Запись сначала полностью кодируется в память. Если encoding завершился ошибкой или payload превышает лимит, предыдущее рабочее значение не изменяется. Cleanup invalid snapshot выполняется best-effort и не подменяет уже определённый `missing` ошибкой хранилища.

Compare-and-remove защищает от удаления нового snapshot только в single-writer режиме, когда все операции идут через один `UserDefaultsKeyValueStore` actor. `UserDefaults` не даёт транзакционный compare-and-remove между process/app extension. Для shared App Group нужен отдельный транзакционный adapter.

## Atomic state для финансовых операций

`PendingApplePurchaseStore` и `PendingRUCheckoutStore` используют CAS-методы не
как оптимизацию, а как safety contract:

- begin/save — `insertIfMissing`, чтобы новая composition не перезаписала старый
  платёж;
- смена Apple-фазы — `replace(ifMatching:)` по точному attempt;
- terminal clear — `remove(ifMatching:)` по прочитанному record и точному
  attempt/session;
- storage error, corruption, schema/version mismatch — fail-closed
  `.unavailable`, который остаётся blocker-ом общего financial gate.

Оба record имеют один app-wide key на стабильный `applicationIdentifier`, но
содержат originating subject. Это позволяет новой login identity увидеть факт
блокировки, не получая права reconcile/poll/clear чужую операцию.

`app-wide` означает «на время существования installation», а не cloud backup.
После удаления приложения эти записи пропадут. Backend notifications,
idempotent purchase ledger и `RecoverCustomerAccessUseCase` закрывают reinstall
сценарий; локальный pending store не может быть единственным доказательством
покупки.

Custom `KeyValueStoreProtocol` обязан сравнивать весь переданный
`KeyValueStoreEntry` и выполнять compare+mutation атомарно в своём concurrency
scope. Custom `CacheRepositoryProtocol` обязан сохранить те же свойства. Простая
реализация «read, затем обычный write/remove» нарушает финансовый контракт. Для
нескольких processes/extensions нужен storage с межпроцессной транзакцией; одного
actor вокруг `UserDefaults` недостаточно.

## Ограничения UserDefaults adapter

- Значение должно быть небольшим. Per-entry лимит по умолчанию — 512 KiB; host может задать меньший. Это не общая disk/memory quota: количество ключей ограничивает host.
- JSON сначала целиком кодируется в памяти и только потом сравнивается с лимитом. Это нужно, чтобы encoding-ошибка не повредила старый snapshot, и ещё одна причина не класть сюда большие payload.
- При чтении oversized entry наружу actor передаётся только SHA-256 fingerprint и размер, а не весь blob; fingerprint нужен для compare-and-remove.
- Для изображений, видео, больших каталогов и других тяжёлых payload нужен отдельный adapter к `KeyValueStoreProtocol`.
- `UserDefaults` создаётся и используется только внутри actor-adapter. Вызов `synchronize()` не нужен.
- Namespace, key name и schema ID — это безопасные стабильные идентификаторы. Не включайте в них email, user ID или другие PII.
- Не сохраняйте API keys, bearer-токены, payment URL, receipt payload, полный
  user ID и другие секреты/PII в общий cache. Единственное узкое исключение —
  явно введённый receipt email из RU payment form: UI сохраняет его под
  отдельным app-configurable key, не включает в cache envelope/log/analytics и
  использует только для следующего запроса чека.
- Entitlement-cache используется только по правилам `EntitlementEngine`: свежий assertion или ограниченный active-only grace. Сам факт наличия записи не является бессрочным доказательством premium.
- Composite Adapty + StoreKit остаётся одним логическим source и пишет ровно один assertion `apple + subject`. Внутренний Adapty SDK-cache с provenance `.unqualified` не становится fresh engine assertion, не обновляет TTL и не создаёт отрицательную запись.

## Ручная проверка example

Проверка специально разделена на разные процессы, чтобы не имитировать persistence в памяти:

1. Запустите `BroadAppTemplate` с `-bootstrap-seed-cache`. Приложение запишет envelope с TTL `0` и перейдёт в `ready`.
2. Полностью остановите приложение.
3. Запустите его с `-bootstrap-stale-cache`. Новый процесс прочитает сохранённый snapshot, выполнит имитированный network refresh, получит timeout и откроет основной экран в `degraded`.
4. Полностью остановите и ещё раз запустите `-bootstrap-stale-cache`. Результат снова должен быть `degraded`: это подтверждает, что сетевой сбой не удалил stale-cache.

Если выполнить второй сценарий до seed, bootstrap предсказуемо перейдёт в non-retryable `failed` и объяснит, что локального snapshot нет.

### Entitlement-cache

Для ручной проверки late-timeout запустите изолированный timeout-fixture:

```bash
xcrun simctl terminate booted com.broadapps.platform.template
xcrun simctl launch booted com.broadapps.platform.template \
  -app-flow-paywall-only \
  -entitlement-timeout
```

Engine завершит проверку через `250 ms` как `unresolved`, хотя Adapty fixture-verifier вернёт active через `1.5 s`, а StoreKit fixture-verifier уже ответил inactive. Подождите дольше `1.5 s`: route не должен измениться.

Отдельный `-entitlement-store-kit-fallback` запускает оба verifier-а параллельно: Adapty даёт `unresolved`, StoreKit своевременно подтверждает `active`, поэтому route — `main`, а namespace `entitlement-source-v1.store-kit-fallback` может содержать нормальный active assertion.

После полной остановки приложения можно проверить fixture-suite напрямую:

```bash
ENTITLEMENT_APP_DATA=$(xcrun simctl get_app_container \
  booted com.broadapps.platform.template data)

plutil -p "$ENTITLEMENT_APP_DATA/Library/Preferences/com.broadapps.platform.template.entitlement-fixture.plist" \
  2>/dev/null | rg 'entitlement-source-v1\.timeout'
```

Команда не должна найти запись timeout-namespace: source проиграл deadline и не получил право на cache write. Каждый fixture имеет namespace `entitlement-source-v1.<scenario>`, поэтому записи `active`, `inactive`, `unknown` и `store-kit-fallback` на эту проверку не влияют. Все `-entitlement-*` флаги и ожидаемые результаты описаны в [Entitlements](Entitlements.md#ручная-acceptance).
