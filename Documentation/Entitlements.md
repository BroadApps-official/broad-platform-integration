# Entitlement Engine: единое право на premium

`BroadMonetization` содержит generic Entitlement Engine и production adapters для трёх logical authority: Apple через verified StoreKit со строгой Adapty freshness boundary, основной BroadApps backend через `GET /api/users/me` и optional RU billing backend. Engine собирает ответы независимых источников, применяет ограниченный timeout, безопасно использует локальный кеш и отдаёт приложению один итог: `active`, `inactive` или `unresolved`.

> [!IMPORTANT]
> StoreKit, основной backend и RU billing имеют отдельные production boundaries. Публичный Adapty profile API тоже изолирован adapter-ом, но не выдаётся за fresh server response: pinned Adapty 3.17.3 может молча вернуть внутренний кеш. Purchase/restore/RU return всегда запускают новую generation и открывают premium только после итогового `active`.

После удаления приложения локальный entitlement cache исчезает, но право на
покупку не исчезает. После login/identity preparation вызовите
`RecoverCustomerAccessUseCase`: он запускает `.startNewGeneration` и заново
опрашивает StoreKit, primary backend и подключённый RU backend. Apple subscription
может восстановиться по тому же App Store account; server/RU entitlement требует
того же app account. [Полный reinstall contract →](AccountRecovery.md).

## Что готово сейчас

- три логических источника: `apple`, `primaryBackend`, `ruBilling`;
- независимый repository-контракт для каждого подключённого источника;
- параллельный запуск источников под одним конечным timeout-бюджетом;
- строгая агрегация `active / inactive / unresolved`;
- отдельный versioned-кеш каждого источника и пользователя;
- конечные TTL и offline grace только для подтверждённого `active`;
- защита от записи позднего результата после timeout;
- default single-flight на уровне всего refresh и каждого источника;
- подробный `EntitlementSnapshot` для feature-кода;
- маппинг в простой `EntitlementStatus` для AppFlow;
- регистрация engine через `BroadMonetizationAssembly`;
- единый `AppleEntitlementRepository` для нескольких Apple verifier-ов;
- verified `StoreKitAppleEntitlementVerifier` и append-only каталог premium SKU;
- `AdaptyAppleEntitlementVerifier`, который принимает только доказанно server-validated profile;
- subject-bound HTTP adapter `GET /api/users/me` со строгим BroadApps JSON decoder;
- `PrimaryBackendEntitlementSourceFactory` для подключения `.primaryBackend` к engine;
- subject-bound RU entitlement HTTP client и `RUBillingCompositionFactory`;
- purchase/restore use cases с обязательным `refreshEntitlement(.startNewGeneration)`;
- единый fresh-install recovery для Apple/primary/RU entitlement, token balance
  и RU management status;
- один typed `entitlementResolved` event на принятую generation: только state/freshness/source states и app-generated attempt ID;
- локальные launch fixtures `active`, `inactive`, `unknown`, StoreKit fallback и timeout без test targets.

## Границы engine

Engine не отображает paywall, не открывает payment URL, не назначает Adapty
variation и не синхронизирует произвольный JWS в backend. Variation выбирает
Adapty SDK; остальные действия принадлежат отдельным use cases/adapters. Host
регистрирует только реально настроенные authority. Без переданного engine
`BroadMonetizationAssembly` использует безопасный
`UnknownEntitlementStatusProvider`.

## Три логических источника

```swift
public enum EntitlementSource {
    case apple
    case primaryBackend
    case ruBilling
}
```

| Источник | Что он представляет | Что не должно просачиваться наружу |
|---|---|---|
| `apple` | Проверенный Apple entitlement через Adapty access level или StoreKit adapter | `AdaptyProfile`, `Transaction`, raw SDK error |
| `primaryBackend` | Явный статус основного backend, включая server-side grants | HTTP response, bearer, полный user ID |
| `ruBilling` | Подтверждённый статус RU-подписки | payment URL, email, backend payload |

Это логические источники, а не названия SDK. Например, приложение без Adapty может реализовать `apple` напрямую через StoreKit. Конкретный adapter возвращает только:

```swift
public enum EntitlementSourceResolution {
    case active(EntitlementActiveValidity)
    case inactive
    case unresolved
}
```

- `active` — текущая авторитетная проверка действительно подтвердила доступ;
- `inactive` — текущая авторитетная проверка успешно и явно подтвердила отсутствие доступа;
- `unresolved` — источник не смог дать надёжный ответ.

Timeout, offline, отсутствие авторизации, ошибка декодирования и unverified StoreKit transaction всегда означают `unresolved`, а не `inactive`.
Старый SDK-local cache без надёжного времени валидации тоже означает `unresolved`: adapter не имеет права каждый раз выдавать его за новую проверку и тем самым бесконечно продлевать TTL. Offline fallback принадлежит `VersionedEntitlementCache`, а не скрытому кешу SDK.

## Одна Apple authority: StoreKit + optional Adapty

В `EntitlementEngine` Apple регистрируется ровно один раз как `.apple`. Внутри `AppleEntitlementRepository` все включённые verifier-ы стартуют параллельно:

| Ответы Apple verifier-ов | Результат `.apple` |
|---|---|
| Хотя бы один доказанный `active` | Немедленный `active`; остальные задачи отменяются |
| Все включённые verifier-ы явно `inactive` | `inactive` |
| Нет `active`, но есть `unresolved` | `unresolved` |

Отключённый verifier вообще не добавляется в массив. Это важно: отсутствующий Adapty или StoreKit не должен изображать вечный `inactive` либо блокировать результат вечным `unresolved`.

### StoreKit verifier

`StoreKitAppleEntitlementVerifier` читает `Transaction.currentEntitlements` через изолированный client и принимает только `.verified` transaction. Отмена задачи, unverified record, несовпавший bundle ID или неожиданный тип настроенного продукта дают `unresolved`, если другой verified premium entitlement не дал `active`.

StoreKit использует отдельный `ApplePremiumProductCatalog`:

- каталог содержит полный набор текущих **и исторических** premium SKU;
- ID сравниваются точно и с учётом регистра;
- для каждого ID явно задан тип: auto-renewable, non-consumable или non-renewing с конечной duration;
- consumable не может случайно выдать premium;
- каталог не строится из продуктов текущего Adapty placement или эксперимента.

Это не фильтр paywall. Любое количество продуктов, полученных от Adapty, по-прежнему передаётся в UI один к одному. Entitlement-каталог лишь отвечает на другой вопрос: какие verified Apple transactions дают premium, включая старые SKU, которых больше нет на текущем paywall.

Verified non-consumable даёт `.lifetime`. Auto-renewable, присутствующий в `currentEntitlements`, даёт active; future expiration сохраняется как `.expires`, а возможный billing grace после paid-period — как конечный `.unspecified`, ограниченный общей TTL/grace policy. Auto-renewable без expiration считается противоречивым и даёт `unresolved`. Для non-renewing срок вычисляется по явно настроенной duration от последней purchase date; накопление нескольких покупок требует отдельного transaction ledger/backend и в текущий adapter не входит.

При сборке toolchain с Swift 6.1+ на iOS 18.4+ client использует per-product `Transaction.currentEntitlements(for:)`. Старый Xcode и iOS 17–18.3 используют legacy `Transaction.currentEntitlements`, после чего применяется тот же exact catalog. В legacy scan любая unverified transaction консервативно делает отрицательный результат `unresolved`, потому что неподтверждённому payload нельзя доверять даже для фильтрации. Verified revoked/upgraded record не даёт доступ; полный успешный scan без premium record даёт `inactive`.

Ownership выбирается приложением явно:

- `.appStoreAccount` — premium следует за текущим App Store account и осознанно не привязывается к login внутри приложения;
- `.appAccountToken(token)` — принимаются только transaction с точным token. Transaction другого app-user игнорируется, а релевантная legacy transaction без token даёт `unresolved`, а не ложный `inactive`.

Одна лишь проверка `EntitlementSubject` не доказывает ownership StoreKit transaction. При login/logout host пересобирает engine, а для user-bound premium обязан выбрать `.appAccountToken` и использовать тот же стабильный token при purchase.

### Почему обычный `Adapty.getProfile()` не является fresh

В pinned Adapty 3.17.3 `getProfile()` пытается обратиться к API, но при сетевой ошибке внутри SDK возвращает cached profile. Публичный результат не содержит cache origin, `fetchedAt` или force-refresh policy. Повторный offline-вызов поэтому не имеет права заново подтверждать access level и продлевать наш TTL.

`AdaptySDKEntitlementProfileClient` честно маркирует любой успешно прочитанный SDK profile как `.unqualified`. `AdaptyAppleEntitlementVerifier` такой результат отклоняет и возвращает `unresolved`. Он принимает `active`/`inactive` только от client-а, который для текущего вызова возвращает `.serverValidated(profile)` и гарантирует привязку к тому же `EntitlementSubject`.

> [!WARNING]
> Не добавляйте `AdaptyAppleEntitlementVerifier` с обычным `AdaptySDKEntitlementProfileClient` в production-массив verifier-ов: он предсказуемо будет `unresolved` и не позволит получить общий `inactive`. Factory по умолчанию включает только строгий StoreKit verifier. Qualified Adapty client можно добавить позже через собственный свежий backend/profile boundary.

При server-validated profile проверяется только настроенный access-level ID. `willRenew == false` не означает inactive, пока сам access level активен. Lifetime определяется только `isLifetime`; `nil expiresAt` не превращается в lifetime автоматически. Refund, несовпавший subject и противоречивые даты дают `unresolved`.

## Основной BroadApps backend

`URLSessionPrimaryBackendClient` читает текущий статус из `GET /api/users/me`. Это не историческая запись и не SDK-cache: только успешный текущий HTTP 200 с валидным JSON может дать `active` или `inactive`.

Адаптер принимает реальный BroadApps contract. Лишние поля `id`, `apphud_id`, `tokens` и другие безопасно игнорируются. Для entitlement используются:

```json
{
  "app_bundle": "com.example.app",
  "subscription_active": true,
  "subscription_expires_at": "2027-07-19T11:46:10.514689Z"
}
```

- `subscription_active` обязателен и должен быть JSON boolean;
- `subscription_expires_at` может быть ISO 8601 string или `null`; microseconds вида `.514689Z` поддерживаются;
- `app_bundle` проверяется по выбранной policy; для production рекомендуется `.required`;
- optional `subscription_lifetime: true` поддерживает явный lifetime grant без expiration.

| Текущий ответ | Resolution |
|---|---|
| `subscription_active: false` | `inactive` |
| `true` и future expiration | `active(.expires)` |
| `true` и `null` expiration | `active(.unspecified)`, всё равно ограниченный TTL/grace |
| `true`, lifetime и `null` expiration | `active(.lifetime)` |
| Expired active, lifetime с expiration, subject/bundle mismatch | `unresolved` |
| Timeout, cancellation, no auth, redirect, non-200, oversized/malformed response | `unresolved` |

Безопасность задана по умолчанию: только HTTPS endpoint без credentials/query/fragment, bearer только в `Authorization`, ephemeral session без URL-cache и cookies, запрет redirect и потоковый limit response body. Credential не имеет публичного raw value, redacted даже при reflection и не попадает в cache или логи. Raw response/error тоже не логируются.

`SubjectAuthorizationProviderProtocol` — trust boundary приложения. Он обязан вернуть access token именно той login-session, из которой построен запрошенный `EntitlementSubject`. Platform не принимает raw user ID и поэтому не пытается сравнить его с `id` из JSON. `/users/me` привязывает ответ к bearer на server-side; provider привязывает bearer к нашему pseudonymous subject. При login/logout весь dependency bundle пересоздаётся.

Минимальное подключение:

```swift
let backendClient = URLSessionPrimaryBackendClient(
    configuration: PrimaryBackendHTTPConfiguration(
        endpointURL: AppBackend.currentUserURL,
        bundleValidation: .required(expected: AppIdentity.bundleIdentifier)
    ),
    authorizationProvider: AppSubjectAuthorizationProvider(session: userSession)
)

let backendRegistration = PrimaryBackendEntitlementSourceFactory(
    client: backendClient
).makeRegistration(
    configuration: PrimaryBackendSourceConfiguration(
        subject: entitlementSubject,
        freshnessPolicy: EntitlementFreshnessPolicy(
            timeToLive: 5 * 60,
            offlineActiveGrace: 24 * 60 * 60
        )
    )
)
```

`AppSubjectAuthorizationProvider`, `AppBackend` и `AppIdentity` принадлежат host-приложению. Если backend имеет другую JSON-схему, host реализует `PrimaryBackendEntitlementClientProtocol` и сохраняет ту же provenance/subject semantics; network DTO не выносится в Domain ради одной вариации backend.

## Правило агрегации

Engine сначала оценивает каждый настроенный источник с учётом его freshness-policy, затем строит общий snapshot.

| Оценённые источники | Итог |
|---|---|
| Есть хотя бы один пригодный `active` | `active` |
| Все настроенные источники имеют пригодный `inactive` | `inactive` |
| Есть `unresolved`, а пригодного `active` нет | `unresolved` |
| Источники не настроены | `unresolved` |

Один `inactive` никогда не отменяет `active` другого источника. Например, временно отстающий backend не может отозвать уже подтверждённый Apple entitlement.

`active` считается пригодным, когда он:

- подтверждён текущим refresh и всё ещё находится до `freshUntil`; или
- находится внутри TTL; или
- находится внутри разрешённого active-only offline grace;
- и при этом фактическая дата окончания подписки ещё не наступила.

Для общего active validity действуют понятные правила:

- любой подтверждённый lifetime делает общий результат lifetime;
- `unspecified` остаётся `unspecified`, а не превращается в lifetime;
- среди известных expiration dates выбирается самая поздняя.

## Почему `unresolved` не равен `inactive`

Если запрос не завершился, платформа не знает, есть подписка или нет. Показать обязательный paywall или отозвать premium в такой ситуации — ложное продуктовое решение.

Поэтому:

- неуспешная проверка не записывает новый отрицательный статус;
- свежий кеш остаётся доступным;
- истёкший `inactive` становится `unresolved`;
- истёкший `active` может использоваться только внутри отдельно заданного grace;
- после окончания grace результат становится `unresolved`, даже если когда-то в кеше был `active`.

## TTL и offline grace

Каждый источник получает собственную конечную policy:

```swift
let applePolicy = EntitlementFreshnessPolicy(
    timeToLive: 15 * 60,
    offlineActiveGrace: 24 * 60 * 60
)
```

Числа выше — только пример. Их выбирает приложение по требованиям конкретного backend и продукта.

У policy две независимые границы:

- `timeToLive` — сколько времени подтверждённый `active` или `inactive` остаётся свежим;
- `offlineActiveGrace` — сколько дополнительного времени можно сохранить только прежний `active`, если новый ответ получить невозможно.

Grace никогда не применяется к `inactive`. Он также не продлевает настоящую дату окончания подписки: effective deadline ограничен minimum из policy, сохранённой границы и `expiresAt`.

Все интервалы обязаны быть конечными. `unspecified` означает «источник не прислал срок», но всё равно ограничивается TTL и grace. Для lifetime существует отдельное значение `.lifetime`; `.distantFuture` как подмена неизвестного срока не нужна.

## Кеш без PII

`VersionedEntitlementCache` хранит каждый источник отдельно через `CacheRepositoryProtocol`. Текущая схема имеет стабильный schema ID и версию `1`.

Физический scope состоит из:

```text
logical source + entitlement subject
```

Для subject есть два режима:

- `.anonymous` — если приложение ещё не имеет стабильной identity;
- `.fingerprinted(...)` — если host уже получил непрозрачный 32-byte fingerprint пользователя.

```swift
let subject = EntitlementSubject.fingerprinted(
    EntitlementSubjectFingerprint(bytes: opaqueFingerprint)
)
```

`opaqueFingerprint` должен содержать ровно 32 байта. Платформа намеренно не принимает raw user ID, email или Adapty profile ID: host готовит псевдоним до вызова API. Используйте keyed HMAC или отдельный случайный pseudonymous ID; обычный SHA-256 от предсказуемого email/user ID недостаточен. Полный идентификатор нельзя помещать в cache key, payload или лог.

В записи находятся только:

- логический source;
- anonymous-marker или opaque fingerprint;
- подтверждённый `active`/`inactive`;
- active validity;
- `validatedAt`, `freshUntil`, `activeGraceUntil`.

`unresolved` не записывается. Повреждённая запись, несовпавшие source/subject и структурно неверные даты всегда отвергаются. Универсальный Core-cache может безопасно очистить повреждённый envelope через compare-and-remove; feature-level запись без такого snapshot-token оставляется в storage, чтобы конкурентное чтение не удалило более новое значение.

Внешний storage retention кеша тоже конечный и служит дополнительной границей чтения. Истёкшая запись больше не используется, даже если storage физически удалит её позднее. Использовать assertion дольше доменных TTL/grace агрегатор всё равно не позволит.

## Timeout и поздний ответ

Все настроенные источники стартуют параллельно и получают один общий deadline:

```swift
timeoutPolicy: .seconds(3)
```

Если источник не успел, его результат для текущего refresh становится `unresolved`. Engine использует подходящий прежний assertion, если он ещё допустим по TTL/grace.

Cache пишет только результат, который выиграл race до deadline. Позднее завершение некооперативного SDK-вызова не может записать cache от имени уже завершившегося refresh и не может изменить уже возвращённый snapshot.

## Single-flight

Если несколько экранов одновременно вызывают default `refreshEntitlement(policy: .joinInFlight)`, engine не создаёт несколько одинаковых сетевых волн. Все callers ожидают один общий in-flight refresh.

Каждая `EntitlementSourceRegistration` дополнительно имеет собственный execution gate. Обычные concurrent callers присоединяются к одному вызову source repository. Явная policy `.startNewGeneration` прерывает старую generation и запускает новую; её нужно использовать только для осознанного force-refresh.

`latestEntitlement()` не запускает новый refresh, но повторно оценивает последний session assertion на текущем времени. Поэтому истёкшие TTL, grace и реальный expiration не могут остаться историческим `active`. До первой проверки метод возвращает `nil`.

## Подключение Apple source и engine

Сначала host объявляет полный entitlement-каталог. Константы принадлежат конкретному приложению; platform package не хранит app-specific SKU:

```swift
let appleCatalog = ApplePremiumProductCatalog(
    entries: AppProducts.allCurrentAndHistoricalPremiumEntries
)

let appleRegistration = AppleEntitlementSourceFactory().makeRegistration(
    configuration: AppleEntitlementSourceConfiguration(
        subject: entitlementSubject,
        freshnessPolicy: EntitlementFreshnessPolicy(
            timeToLive: 15 * 60,
            offlineActiveGrace: 24 * 60 * 60
        ),
        appBundleIdentifier: AppIdentity.bundleIdentifier,
        productCatalog: appleCatalog,
        ownershipPolicy: .appStoreAccount
    )
)
```

`AppleEntitlementSourceFactory` создаёт один `.apple` registration с реальным StoreKit client. Если приложение имеет собственный client, который действительно возвращает current server-validated Adapty profile, соответствующий `AdaptyAppleEntitlementVerifier` передаётся через `additionalAuthoritativeVerifiers`. Обычный `AdaptySDKEntitlementProfileClient` туда не добавляется.

Затем composition root собирает cache и engine:

```swift
let entitlementCache = VersionedEntitlementCache(
    repository: cacheRepository
)

let entitlementEngine = EntitlementEngine(
    registrations: [
        appleRegistration,
        backendRegistration
    ],
    subject: entitlementSubject,
    cache: entitlementCache,
    timeoutPolicy: .seconds(3),
    analytics: monetizationAnalytics
)

let monetizationAssembly = BroadMonetizationAssembly(
    entitlementEngine: entitlementEngine
)
```

Регистрировать нужно только реально настроенные логические источники и verifier-ы. Отключённые Adapty/RU billing не добавляются как вечный `inactive` или `unresolved`.

Engine неизменяемо привязан к одному `EntitlementSubject`. При login, logout, Adapty identify или ротации anonymous identity composition root создаёт новый subject, repositories, registrations и engine, затем заменяет весь согласованный dependency bundle. Registration от старого engine повторно не используется: так результат пользователя B нельзя записать в scope пользователя A.

Convenience-init assembly регистрирует один engine сразу как:

- `EntitlementRepositoryProtocol`;
- `RefreshEntitlementUseCaseProtocol`;
- `EntitlementStatusProviderProtocol`.

Views не резолвят эти зависимости. Composition root передаёт repository/use case во ViewModel, а простой status provider — в `AppFlowCoordinator`.

## Связь с AppFlow

Engine маппит подробный доменный результат в минимальный AppFlow-контракт:

| Entitlement Engine | AppFlow |
|---|---|
| `.active` | `.active` |
| `.inactive` | `.inactive` |
| `.unresolved` | `.unknown` |

AppFlow использует этот статус только для первичного маршрута:

- `active` пропускает initial paywall;
- `inactive` показывает включённый initial paywall;
- `unknown` открывает бесплатный `main`, не выдаёт premium и не сохраняет paywall checkpoint.

После purchase/restore use case запускает новую проверочную волну, не присоединяясь к запросу, который мог начаться до транзакции:

```swift
let snapshot = await entitlementRepository.refreshEntitlement(
    policy: .startNewGeneration
)
```

Только новый snapshot с `state == .active` разрешает вызвать:

```swift
appFlowCoordinator.subscriptionDidBecomeActive()
```

Сам факт успешного ответа purchase API не является подтверждением entitlement.

Ask-to-Buy/outcome-unknown сохраняются отдельным durable Apple intent и не
превращаются ни в active, ни в inactive. Один verified same-bundle purchase
`Transaction.updates` bridge и foreground history recovery переводят intent в
`transactionConfirmed`; для premium blocker снимается только после нового current
authoritative active. User acknowledgement его не очищает. Generic premium use
case также отклоняет consumables до charge: token delivery требует отдельного
durable exactly-once fulfillment authority, а не entitlement snapshot.

## Правила adapters

- Adapty adapter проверяет настроенный access level, а не наличие любого продукта, и принимает только qualified server profile.
- StoreKit adapter принимает только verified transaction из полного entitlement-каталога.
- Unverified transaction возвращает `unresolved` и не отправляется в backend sync.
- Backend/RU adapter возвращает `inactive` только после валидного явного отрицательного ответа.
- HTTP timeout, decoding error, DNS, отсутствие токена и частичный ответ возвращают `unresolved`.
- Checkout, `pending` или возврат из Safari не дают optimistic premium.
- Если RU status проверяется по нескольким identity/endpoints, `inactive` возможен только после успешной отрицательной проверки всех настроенных вариантов.
- Все продукты paywall по-прежнему передаются в UI без фильтрации. Список показанных продуктов не используется как доказательство premium.

## Ручная acceptance

В проекте намеренно нет test targets. Базовый локальный gate:

```bash
./Scripts/lint.sh
./Scripts/build.sh
```

Для проверки AppFlow включите paywall-only конфигурацию и ровно один entitlement fixture:

| Launch arguments | Ответы Apple verifier-ов | Ожидаемый route |
|---|---|---|
| `-app-flow-paywall-only -entitlement-active` | Adapty `active`, StoreKit `inactive` | `main` |
| `-app-flow-paywall-only -entitlement-inactive` | Оба явно `inactive` | `initial-paywall` |
| `-app-flow-paywall-only -entitlement-unknown` | Adapty unqualified cache → `unresolved`, StoreKit `inactive` | `main`, premium не выдан |
| `-app-flow-paywall-only -entitlement-store-kit-fallback` | Adapty unqualified cache → `unresolved`, StoreKit `active` | `main` с подтверждённым premium |
| `-app-flow-paywall-only -entitlement-timeout` | Adapty отдаёт некоперативный `active` через `1.5 s`, StoreKit `inactive`; deadline `250 ms` | `main` через `unknown`; поздний ответ ничего не меняет |

После установки собранного example на booted Simulator:

```bash
xcrun simctl terminate booted com.broadapps.platform.template
xcrun simctl launch booted com.broadapps.platform.template \
  -app-flow-paywall-only \
  -entitlement-timeout
```

Example показывает реальные route-specific экраны: `BroadOnboardingView`, `BroadPaywallView` и `ExampleMainView`. Дополнительно route можно проверить в Accessibility Inspector по identifier `broadapps.app-flow.root`; value имеет вид `route=main;fixture=store-kit-fallback`, `route=main;fixture=timeout` или `route=initial-paywall;fixture=inactive`.

Каждый fixture имеет свой namespace `entitlement-source-v1.<scenario>`, поэтому ранее запущенный `active` не загрязняет `timeout`. Подождите больше `1.5 s` — route не должен измениться. Это проверяет, что поздний ответ не меняет текущий snapshot.

Чтобы отдельно проверить отсутствие поздней записи, полностью остановите приложение и посмотрите fixture-suite:

```bash
ENTITLEMENT_APP_DATA=$(xcrun simctl get_app_container \
  booted com.broadapps.platform.template data)

plutil -p "$ENTITLEMENT_APP_DATA/Library/Preferences/com.broadapps.platform.template.entitlement-fixture.plist" \
  2>/dev/null | rg 'entitlement-source-v1\.timeout'
```

Команда не должна найти запись именно timeout-namespace: source проиграл deadline и не получил право на cache write. У `store-kit-fallback` отдельный namespace `entitlement-source-v1.store-kit-fallback`; его своевременный StoreKit active, наоборот, может создать нормальный active assertion. Записи других fixture-сценариев на timeout-проверку не влияют.

Fixture-флаги взаимоисключающие; несколько `-entitlement-*` завершают запуск precondition-ошибкой. Без entitlement-флага example использует локальный inactive/active-after-purchase engine. По умолчанию включён полный flow с onboarding; `-app-flow-main-only` выбирает `.mainOnly`, а `-app-flow-paywall-only` отключает только onboarding.

Минимальная ручная матрица для fixture-repositories:

| Сценарий | Ответы источников | Ожидание |
|---|---|---|
| Active wins | Apple `active`, backend `inactive`, RU `unresolved` | Общий `active` |
| Confirmed inactive | Все настроенные источники `inactive` | Общий `inactive` |
| Partial failure | Один `inactive`, один `unresolved` | Общий `unresolved` |
| Fresh fallback | Сначала `active`, затем timeout до конца TTL | `active / cached` |
| Offline grace | Cached active после TTL, но до grace deadline | `active / grace` |
| No inactive grace | Cached inactive после TTL | `unresolved` |
| Real expiration | Cached active после `expiresAt` | `unresolved` |
| Late result | Источник завершился после общего deadline | Текущий snapshot не меняется, поздний refresh не пишет cache |
| Concurrent refresh | Несколько callers стартуют одновременно | Один вызов каждого source repository |
| Identity isolation | Один source, разные fingerprints | Кеш одного subject не читается другим |

Persistence-сценарии проверяются в разных process: после seed приложение нужно полностью остановить и запустить снова.

Связанные документы: [Architecture](Architecture.md), [Cache и offline](CachingAndOffline.md), [AppFlow](AppFlow.md).
