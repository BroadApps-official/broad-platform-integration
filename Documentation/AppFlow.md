# AppFlow: запуск, onboarding, initial paywall и main

`BroadUIFlows` содержит единый маршрут первого запуска приложения. AppFlow решает, какой экран открыть, но не запускает SDK, не покупает подписку и не проверяет entitlement самостоятельно.

## Маршрут

```text
launch ─→ onboarding ─→ initialPaywall ─→ main
  │          └─(skip paywall)────────→ main
  ├─(skip onboarding)─→ initialPaywall ─→ main
  └─(skip both)───────────────────→ main
```

- `launch` — bootstrap/loader ещё не открыл первый продуктовый route.
- `onboarding` — onboarding включён и ещё не завершён.
- `initialPaywall` — выбранная политика требует первичный paywall, а entitlement точно `inactive`.
- `main` — основной маршрут. В рамках обычной сессии это конечное состояние.

Onboarding и initial paywall можно отключать независимо, поэтому ненужные шаги пропускаются. При политике `onceAfterOnboarding` вернувшийся пользователь с уже пройденным initial paywall перейдёт из `launch` сразу в `main`. При `everyColdLaunchWhileInactive` новый process снова проверит entitlement и покажет paywall только при подтверждённом `inactive`.

`main` не переводится обратно в `initialPaywall` из-за позднего ответа SDK или смены entitlement. Премиальный content внутри `main` по-прежнему защищается актуальным entitlement, а повторные продажи при необходимости открываются отдельным placement/feature-flow.

### Ветка Special Offer после крестика

AppFlow не ставит Special Offer вместо `initialPaywall`. Если host включил
downsell, он подключается только к явному закрытию первого paywall без покупки:

```text
initialPaywall
  ├─ purchased/restored → entitlement active → main
  └─ close (крестик) → resolver → specialOffer или main
```

Пока resolver работает, host оставляет пользователя в конечном loader-state и
не вызывает `initialPaywallDismissed()`. Этот метод вызывается после
отрицательного resolution либо после закрытия Special Offer. Так policy не
считает ветку завершённой раньше времени. Полный контракт и reference экранов:
[Special Offer](SpecialOffer.md) · [README](../README.md#special-offer-sequence).

## Конфигурация

`AppFlowConfiguration` требует явно задать оба шага. Скрытых default-решений нет.

```swift
let fullFlow = AppFlowConfiguration(
    onboarding: .enabled,
    initialPaywall: .onceAfterOnboarding(allowsClose: false)
)

let closableOncePaywall = AppFlowConfiguration(
    onboarding: .enabled,
    initialPaywall: .onceAfterOnboarding(allowsClose: true)
)

let everyColdLaunchPaywall = AppFlowConfiguration(
    onboarding: .enabled,
    initialPaywall: .everyColdLaunchWhileInactive(allowsClose: true)
)

let onboardingOnly = AppFlowConfiguration(
    onboarding: .enabled,
    initialPaywall: .disabled
)

let paywallOnly = AppFlowConfiguration(
    onboarding: .disabled,
    initialPaywall: .onceAfterOnboarding(allowsClose: true)
)

let mainOnly: AppFlowConfiguration = .mainOnly
```

- `.onceAfterOnboarding(allowsClose:)` — initial paywall разрешается один раз на установку; подтверждённый dismissal или active сохраняет checkpoint.
- `.everyColdLaunchWhileInactive(allowsClose:)` — каждый новый process заново проверяет entitlement; dismissal пропускает paywall только в текущем запуске и не сохраняет permanent skip.
- `.disabled` — initial paywall автоматически не показывается.
- `allowsClose: false` запрещает close-action; `true` разрешает host передать закрытие в coordinator.
- `.mainOnly` — оба шага отключены; coordinator переходит в `main` без чтения progress storage и entitlement provider.

`AppFlowConfiguration` описывает только порядок экранов. Placement ID, продукты, backup-placement и доступность special offer принадлежат monetization-конфигурации приложения, а не AppFlow.

## Checkpoint и решение о route

AppFlow хранит только монотонный прогресс:

```text
start → onboardingCompleted → initialPaywallResolved
```

Назад checkpoint не откатывается. `initialPaywallResolved` означает, что одноразовый initial gate уже разрешён. Он используется только политикой `onceAfterOnboarding` и не является доказательством активной подписки. Политика `everyColdLaunchWhileInactive` намеренно игнорирует этот marker.

Ниже показано решение state machine. Если статус помечен как «не читается», coordinator не вызывает entitlement provider.

| Checkpoint | Политика | Entitlement | Route | Что фиксируется |
|---|---|---|---|---|
| `start` | onboarding включён | не читается | `onboarding` | ничего |
| `start` / `onboardingCompleted` | `onceAfterOnboarding` | `active` | `main` | `initialPaywallResolved`, best-effort |
| `start` / `onboardingCompleted` | `onceAfterOnboarding` | `inactive` | `initialPaywall` | ничего |
| `start` / `onboardingCompleted` | `onceAfterOnboarding` | `unknown` | `main` | ничего |
| `initialPaywallResolved` | `onceAfterOnboarding` | не читается | `main` | ничего |
| любой завершённый onboarding | `everyColdLaunchWhileInactive` | `active` | `main` | ничего |
| любой завершённый onboarding | `everyColdLaunchWhileInactive` | `inactive` | `initialPaywall` | ничего |
| любой завершённый onboarding | `everyColdLaunchWhileInactive` | `unknown` | `main` | ничего |
| любой | `disabled` | не читается | `main` | ничего |

Если оба шага выключены, `.mainOnly` открывает `main` синхронно. Если onboarding включён, он всегда завершается раньше initial paywall: даже уже активная подписка не прерывает onboarding.

## Почему `unknown` — это не `inactive`

`EntitlementStatus.unknown` означает, что платформа не смогла доказать ни активный, ни неактивный статус. Такое возможно при timeout, отсутствии сети или ещё не закончившейся синхронизации SDK.

Правила строгие:

- `unknown` не показывает paywall как будто подписки точно нет;
- `unknown` открывает обычный `main`, чтобы не оставлять пользователя в бесконечном `launch`;
- `unknown` не разблокирует premium-feature;
- `unknown` не записывает `initialPaywallResolved`, поэтому при следующем запуске статус можно проверить ещё раз.

Доступ к premium даёт только подтверждённый `active`.

На чистой установке host сначала восстанавливает login и тот же
`EntitlementSubject`, затем запускает `RecoverCustomerAccessUseCase` и только
после этого передаёт authoritative entitlement в AppFlow. Если сеть недоступна,
результат остаётся `unknown`: бесплатный `main` доступен, premium закрыт, а
recovery безопасно повторяется после появления связи. Token balance и RU status
не принадлежат AppFlow и приходят только из backend snapshot.

[Восстановление после переустановки →](AccountRecovery.md) ·
[Обрыв сети →](NetworkInterruptions.md)

## Source of truth для entitlement

Единый source of truth находится в `BroadMonetization` за границей `EntitlementStatusProviderProtocol`:

```swift
public protocol EntitlementStatusProviderProtocol: Sendable {
    func currentStatus() async -> EntitlementStatus
}
```

Готовый `EntitlementEngine` агрегирует настроенные логические источники `apple`, `primaryBackend` и `ruBilling`, но наружу для AppFlow возвращает только `active`, `inactive` или `unknown`. SDK-модели и raw errors не переходят в `BroadUIFlows`.

Внутренний доменный результат engine маппится так:

| Entitlement Engine | AppFlow |
|---|---|
| `.active` | `.active` |
| `.inactive` | `.inactive` |
| `.unresolved` | `.unknown` |

Engine запускает источники параллельно под общим ограниченным deadline. Timeout, offline, отсутствие авторизации, unverified transaction и неклассифицированная SDK/backend-ошибка дают `.unresolved`, а значит AppFlow получает `.unknown`. `AppFlowCoordinator` не добавляет второй timeout вокруг provider.

Adapty и StoreKit внутри engine не являются двумя source: `AppleEntitlementRepository` объединяет их в один `.apple` assertion. StoreKit active подтверждает Apple даже при Adapty `unresolved`; если StoreKit inactive, а Adapty profile имеет только unqualified SDK-cache, итог Apple остаётся `unresolved`, и AppFlow получает `unknown`.

`BroadMonetizationAssembly` по умолчанию регистрирует `UnknownEntitlementStatusProvider`. Это безопасный placeholder, а не production-проверка подписки. Когда host собрал source repositories и cache, один generic engine можно зарегистрировать сразу за всеми entitlement-контрактами:

```swift
let monetizationAssembly = BroadMonetizationAssembly(
    entitlementEngine: entitlementEngine
)
```

Generic aggregation, bounded execution, cache, DI, StoreKit, основной backend и RU entitlement adapters готовы. Adapty freshness boundary не принимает скрытый SDK-cache за fresh server response. Purchase/restore и RU return запускают новую generation, а adaptive paywall закрывает flow только после подтверждённого active. Полный контракт: [Entitlements](Entitlements.md).

Нельзя использовать `BroadMonetizationModule.isAdaptyLinked` как entitlement. Этот флаг говорит только о наличии SDK в build.

## Progress storage

`KeyValueAppFlowProgressRepository` хранит два независимых versioned marker:

```text
<keyPrefix>.onboarding-completed.v1
<keyPrefix>.initial-paywall-resolved.v1
```

Каждый marker — точное значение `Data([1])`. Пропущенная, повреждённая или неправильно типизированная запись считается незавершённым шагом. Чтение не падает и не повышает checkpoint без валидного marker.

Прогресс монотонен:

- `onboardingCompleted` записывает onboarding-marker;
- `initialPaywallResolved` для `onceAfterOnboarding` сначала пытается записать onboarding-marker, затем paywall-marker; валидный paywall-marker сам по себе означает наивысший checkpoint;
- `advance(to:)` после записи читает фактический checkpoint, поэтому dismissal/onboarding не проходят при неудавшейся записи;
- запись `start` ничего не удаляет и не откатывает.

Эти marker живут в отдельном state store, а не в `CacheRepositoryProtocol`. Для них нет TTL, `fresh/stale`, offline fallback и автоматического cache cleanup. `BroadCoreAssembly` принимает state store отдельно:

```swift
let coreAssembly = BroadCoreAssembly(
    bootstrapSteps: bootstrapSteps,
    cacheRepository: cacheRepository,
    stateStore: UserDefaultsKeyValueStore(
        namespace: "com.example.app.state"
    ),
    logger: logger
)
```

Используйте стабильный app-specific `keyPrefix`. Не включайте в него user ID, email, placement ID или другие PII/секреты.

## События `AppFlowCoordinator`

| Метод | Когда вызывать | Результат |
|---|---|---|
| `startIfNeeded()` | После bootstrap `ready` или `degraded` | Один раз читает progress, при необходимости запрашивает entitlement и выбирает route |
| `onboardingCompleted()` | После реального завершения onboarding | Сохраняет checkpoint; затем открывает paywall или `main` |
| `subscriptionDidBecomeActive()` | Только после проверенного `active` от purchase/restore/entitlement refresh | Запоминает active в текущей сессии; пропускает initial paywall и фиксирует его best-effort |
| `initialPaywallDismissed()` | Только по close-action при `allowsClose == true` | Для `onceAfterOnboarding` сначала фиксирует checkpoint; для `everyColdLaunchWhileInactive` открывает `main` только в текущем process |
| `initialPaywallUnavailable()` | Monetization-слой не смог собрать initial paywall после своей fallback-policy | Открывает `main`, но не фиксирует paywall; следующий launch сможет повторить попытку |
| `restart()` | Явный session reset | Отменяет текущий transition, сбрасывает route в `launch`, но не удаляет persistent progress и не запускает flow повторно сам |

`isTransitionInFlight` можно использовать для блокировки повторного действия. Coordinator сам владеет `Task`, cancellation и generation-проверкой: поздний async-ответ не может перезаписать новый route.

### Purchase или restore во время onboarding

Успешная кнопка purchase/restore сама по себе не доказывает подписку. Сначала monetization-слой должен получить и проверить `active`, и только после этого host вызывает:

```swift
appFlowCoordinator.subscriptionDidBecomeActive()
```

Если `active` подтверждён во время onboarding, текущий onboarding не прерывается. Coordinator запоминает active для этой сессии. Когда onboarding реально завершается, flow идёт сразу в `main`, фиксирует initial paywall как разрешённый и не показывает его даже на один frame.

Если `active` подтверждён на `initialPaywall`, flow сразу открывает `main`. Для `onceAfterOnboarding` запись checkpoint завершается best-effort в фоне; `everyColdLaunchWhileInactive` не создаёт permanent marker и на следующем cold launch снова проверяет entitlement.

## Правила dismissal и unavailable

- Close-action нужно показывать только при `allowsClose == true`.
- При `allowsClose == false` вызов `initialPaywallDismissed()` игнорируется, route остаётся `initialPaywall`.
- При разрешённом close и `onceAfterOnboarding` coordinator сначала записывает checkpoint. Если хранилище не подтвердило запись, `main` не открывается.
- При разрешённом close и `everyColdLaunchWhileInactive` coordinator открывает `main` без paywall-marker; повторного показа в том же process нет, а следующий cold launch снова проверяет entitlement.
- `initialPaywallUnavailable()` нужно вызывать после того, как monetization-слой исчерпал свою стратегию primary/backup placement. AppFlow не угадывает placement и не фильтрует продукты.
- Unavailable открывает `main`, но не сохраняет `initialPaywallResolved`. При новом launch paywall можно попытаться загрузить снова.

## ATT и Rate Us

AppFlow не вызывает ATT. Запрещено вызывать ATT:

- в bootstrap-step;
- в loader/`launch`;
- в `AppFlowCoordinator`;
- в `init` onboarding-экрана;
- до фактического появления первого слайда.

ATT запрашивается только из события «первый onboarding-слайд фактически появился» и защищается one-shot guard владельца onboarding. Повторный SwiftUI `onAppear` не должен создать второй запрос.

Экран Rate Us сам по себе не запрещён: его можно использовать вне onboarding, например в settings или main-flow. Внутри onboarding экрана, слайда или имитации Rate Us быть не должно.

## Подключение в host app

Composition root создаёт dependencies на `@MainActor`. View не обращается к Swinject и не создаёт repository.

```swift
import BroadCore
import BroadMonetization
import BroadUIFlows
import Swinject

@MainActor
final class AppCompositionRoot {
    let appFlowCoordinator: AppFlowCoordinator

    private let assembler: Assembler

    init(
        bootstrapSteps: [BootstrapStep],
        entitlementEngine: EntitlementEngine
    ) {
        let stateStore = UserDefaultsKeyValueStore(
            namespace: "com.example.app.state"
        )
        let assembler = Assembler([
            BroadCoreAssembly(
                bootstrapSteps: bootstrapSteps,
                stateStore: stateStore
            ),
            BroadMonetizationAssembly(entitlementEngine: entitlementEngine),
            BroadUIFlowsAssembly()
        ])

        guard
            let resolvedStateStore = assembler.resolver.resolve(KeyValueStoreProtocol.self),
            let resolvedEntitlements = assembler.resolver.resolve(EntitlementStatusProviderProtocol.self)
        else {
            preconditionFailure("BroadApps platform assemblies are incomplete")
        }

        let progressRepository = KeyValueAppFlowProgressRepository(
            keyValueStore: resolvedStateStore,
            keyPrefix: "com.example.app.app-flow"
        )

        self.assembler = assembler
        appFlowCoordinator = AppFlowCoordinator(
            configuration: AppFlowConfiguration(
                onboarding: .enabled,
                initialPaywall: .onceAfterOnboarding(allowsClose: true)
            ),
            progressRepository: progressRepository,
            entitlementStatusProvider: resolvedEntitlements
        )
    }
}
```

Bootstrap открывает AppFlow только после безопасного результата:

```swift
switch bootstrapState {
case .ready, .degraded:
    appFlowCoordinator.startIfNeeded()
case .idle, .starting, .failed:
    break
}
```

`BroadAppFlowView` — чистый exhaustive renderer. Он не владеет `Task`, не резолвит DI и не добавляет animation, opacity или побочные эффекты:

```swift
struct AppFlowRootView: View {
    @ObservedObject private var coordinator: AppFlowCoordinator

    init(coordinator: AppFlowCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        BroadAppFlowView(
            route: coordinator.route,
            launch: {
                LaunchView()
            },
            onboarding: {
                OnboardingView(
                    onCompleted: coordinator.onboardingCompleted
                )
            },
            initialPaywall: {
                InitialPaywallView(
                    onVerifiedActive: coordinator.subscriptionDidBecomeActive,
                    onDismiss: coordinator.initialPaywallDismissed,
                    onUnavailable: coordinator.initialPaywallUnavailable
                )
            },
            main: {
                MainView()
            }
        )
    }
}
```

Конкретные onboarding/paywall/main screens, тексты, assets и токены принадлежат host app. AppFlow не придумывает app-specific UI и не требует Figma. `BroadAppTemplate` по умолчанию показывает полный flow с тремя onboarding-слайдами и `onceAfterOnboarding`; `-initial-paywall-every-cold-launch` включает повторный cold-launch сценарий, `-initial-paywall-disabled` отключает автоматический paywall, `-app-flow-main-only` включает `.mainOnly`, а `-app-flow-paywall-only` отключает onboarding. Builders используют реальные `BroadOnboardingView`, `BroadPaywallView` и `ExampleMainView`.

## Ручная acceptance-матрица

В проекте нет test targets. Example поддерживает paywall-only route и fixtures двух параллельных Apple verifier-ов:

```bash
xcrun simctl terminate booted com.broadapps.platform.template
xcrun simctl launch booted com.broadapps.platform.template \
  -app-flow-paywall-only \
  -entitlement-inactive
```

Доступны `-entitlement-active`, `-entitlement-inactive`, `-entitlement-unknown`, `-entitlement-store-kit-fallback` и `-entitlement-timeout`; одновременно разрешён только один. Ожидаемые routes соответственно: `main`, `initial-paywall`, `main`, `main`, `main`. В StoreKit fallback fixture оба verifier-а стартуют параллельно: Adapty unresolved, StoreKit active. Timeout возвращает AppFlow `unknown` за `250 ms`, хотя Adapty fixture позже отдаёт active через `1.5 s`; route не должен измениться.

Routes визуально различаются. Фактическое значение дополнительно проверяется через Accessibility Inspector: identifier `broadapps.app-flow.root`, value вида `route=initial-paywall;presentation=subscription-paywall;fixture=inactive` или `route=main;presentation=main;fixture=store-kit-fallback`. После закрытия первого paywall route намеренно остаётся `initial-paywall`, пока downsell не завершён, а поле `presentation` меняется на `special-offer-resolver` и затем `special-offer`.

Без app-flow флага используется полный onboarding + initial paywall flow. `-app-flow-main-only` не читает progress/entitlement. Без `-entitlement-*` example использует локальный inactive/active-after-purchase engine. Fixture-сценарии изолируют cache по namespace, поэтому порядок запуска `active` и `timeout` не влияет на route. Каждый persistence-сценарий проверяйте после полной остановки и нового запуска process. Полная fixture-инструкция: [Entitlements](Entitlements.md#ручная-acceptance).

| № | Конфигурация и исходные данные | Действие | Ожидание |
|---:|---|---|---|
| 1 | `.mainOnly`, чистое state storage | Bootstrap переходит в `ready` | `launch → main`; storage и entitlement provider не читаются |
| 2 | Full flow, `start`, любой entitlement | Вызвать `startIfNeeded()` | `launch → onboarding`; entitlement provider не вызывается |
| 3 | Full flow, `onboardingCompleted`, `inactive` | Запустить flow | `launch → initialPaywall` |
| 4 | `onceAfterOnboarding`, `onboardingCompleted`, `active` | Запустить flow | `launch → main` без frame paywall; paywall-marker записан |
| 5 | Full flow, `onboardingCompleted`, `unknown` | Запустить flow | `launch → main`; premium не включён, paywall-marker не записан; новый process проверяет статус снова |
| 6 | Full flow, `start` | Во время onboarding подтвердить restore, затем завершить onboarding | Onboarding не прерывается; после completion сразу `main`, без мерцания paywall |
| 7 | Paywall `inactive`, `allowsClose: false` | Попытаться вызвать dismissal | Route остаётся `initialPaywall`, checkpoint не меняется |
| 8 | `onceAfterOnboarding`, paywall `inactive`, `allowsClose: true` | Закрыть paywall | После подтверждённой записи checkpoint открывается `main`; новый process не показывает initial paywall |
| 9 | Paywall `inactive` | Передать `initialPaywallUnavailable()` после monetization fallback | Открывается `main`, paywall-marker не записывается; новый process может повторить paywall |
| 10 | Paywall показан | Подтвердить active после purchase/restore | `main` открывается сразу; для `onceAfterOnboarding` checkpoint фиксируется best-effort |
| 11 | Flow уже на `main` | Provider/SDK позже сообщает inactive или завершается старый async-ответ | Нет обратного `main → initialPaywall`; premium-content реагирует через monetization entitlement |
| 12 | Любой persistent checkpoint | Вызвать `restart()` | Route становится `launch`; markers не удаляются; нужен новый `startIfNeeded()` |
| 13 | Bootstrap `failed` | Дождаться terminal bootstrap state | AppFlow остаётся в `launch`; после успешного retry и `ready/degraded` запускается один раз |
| 14 | Onboarding включён | Открыть первый слайд, уйти назад и вернуться | ATT может быть запрошен только после первого фактического appearance и не более одного раза; Rate Us в onboarding отсутствует |
| 15 | Повреждённый/невалидный marker или storage read error | Запустить flow | Невалидный marker не засчитывается; flow без crash выбирает более ранний checkpoint |
| 16 | Storage не может записать marker | Завершить onboarding или закрыть closable paywall | Onboarding остаётся `onboarding`, dismissible paywall остаётся `initialPaywall`; переход не потеряется между process |
| 17 | `everyColdLaunchWhileInactive`, `inactive` | Закрыть paywall и продолжить текущий process | Открывается `main`, paywall-marker не записывается, повторного показа в текущем process нет |
| 18 | `everyColdLaunchWhileInactive`, `inactive` | Полностью остановить и снова запустить app | `initialPaywall` показывается снова |
| 19 | Любая paywall policy, `active` | Сделать cold launch | Сразу `main`; subscription paywall не показывается |
| 20 | `disabled`, любой checkpoint | Сделать cold launch | Сразу `main` после onboarding; entitlement для initial paywall не читается |

Дополнительно проверьте, что transition не добавляет мерцание, затемнение или случайную animation на paywall/product button. Это ответственность конкретного paywall UI; `BroadAppFlowView` сам эффектов не добавляет.
