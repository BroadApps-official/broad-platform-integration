# Bootstrap

`BroadCore` provides one deterministic startup engine. It coordinates app-specific work without importing SwiftUI, Adapty, StoreKit or any host application type.

## State lifecycle

```text
idle → starting ─┬→ ready
                 ├→ degraded
                 └→ failed(error) → retry → starting
```

- `ready`: every critical step completed normally.
- `degraded`: a critical step used a safe fallback, or a background step failed/timed out after the route opened.
- `failed`: a critical step exhausted its retry schedule or timeout budget without a fallback.
- Repeated `start()` calls join the active run. They do not activate an SDK twice.
- `retry()` starts a new generation only from `failed`. Late results from an older generation are ignored.

## Step contract

Every `BootstrapStep` has a unique `BootstrapStepID`, name, criticality, `TimeoutPolicy`, `RetryPolicy` and `@Sendable` async operation.

### Critical

Critical steps execute sequentially in declaration order. Use them only for work required to choose and safely display the first route.

- `.completed` continues normally.
- `.degraded(AppError)` means the step deliberately used a valid fallback or cache. It is not retried.
- A thrown error follows `RetryPolicy`; the final failure produces `.failed`.

### Background

Background steps start after the critical gate has produced `ready` or `degraded`. They run concurrently and never hold the loader. A failure can update `ready` to `degraded`, but never to `failed`.

## Timeout semantics

`TimeoutPolicy.limit` is the total budget for one step, including all attempts and retry delays. There is no infinite timeout.

The coordinator uses a one-shot race instead of a structured task group. When the timeout wins, the coordinator immediately stops waiting and ignores any late result. Every `BootstrapStep` also owns a single-flight gate: if an SDK ignores cancellation, a later retry joins that still-running execution instead of starting a duplicate. Swift cannot forcibly terminate such an SDK call, so non-idempotent activation should normally use `RetryPolicy.none` and keep its own idempotency guard inside the adapter as a second line of protection.

## Retry semantics

`RetryPolicy.delays` contains delays before each retry. Therefore total attempts equal `delays.count + 1`.

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

Only explicitly retryable `AppError` values are retried. Unknown errors are sanitized and treated as non-retryable until an adapter classifies them. `CancellationError` is control flow and never becomes a user-facing failure.

## Error safety

`AppError` stores only:

- a typed kind;
- a user-facing message;
- a sanitized diagnostic code;
- retryability.

Raw SDK errors, payment URLs, access tokens, API keys and full user identifiers do not cross the public boundary.

The host supplies timeout and unknown-error messages through `BootstrapErrorMessages`. This keeps localization and product tone outside `BroadCore`.

## Logging

The coordinator emits closed `BroadLogEvent` values through `BroadLoggerProtocol`. It records lifecycle, state transitions, step kind/index, attempt count and safe `AppError.Kind`. It deliberately does not record `BootstrapStepID`, step name, user-facing message, diagnostic code or raw error.

A terminal step event is emitted only after the timeout race has resolved. A non-cooperative SDK that finishes after timeout cannot create a false success event. See [Logging](Logging.md) for the complete privacy contract and OSLog setup.

## Presentation mapping

`AppBootstrapState` remains the engine contract and carries bootstrap-specific `ready/degraded/failed` lifecycle semantics. The coordinator tracks run generations internally. The example ViewModel keeps module content in `LoadableState<[ModuleItem]>`: `ready` and `degraded` both make the synchronously built list `loaded`, while a separate render state shows degraded bootstrap health. `failed` maps to content `error`. The module list comes from the associated value, so a refresh can retain already rendered content without changing the coordinator.

Never map every bootstrap `degraded` to content `stale`: a background SDK timeout does not make unrelated content old. Only a typed feature result that explicitly accepts cached data may create `LoadableState.stale`.

See [Loadable state](LoadableState.md) for the complete state table and the distinction between accepted stale fallback and an error that merely retains previous value.

## Dependency injection

Resolve concrete dependencies synchronously, construct steps, and then pass them to `BroadCoreAssembly`.

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

Never capture Swinject `Resolver` or `Container` inside a step. They are composition-root tools, not async dependencies.

## ATT boundary

ATT must not be included in bootstrap. The tracking request belongs to a dedicated adapter and is triggered only after the first onboarding slide has actually appeared.

## Example scenarios

The local `BroadAppTemplate` provides deterministic fake steps without live SDKs:

- no argument: `idle → starting → ready`;
- `-bootstrap-degraded`: a background operation ignores cancellation, the timeout releases the coordinator, and the UI remains available in `degraded`;
- `-bootstrap-failed-once`: the first critical run fails; tapping `Try again` reuses the same registered step and reaches `ready`;
- `-bootstrap-seed-cache`: writes a persisted configuration snapshot with TTL `0` and reaches `ready`;
- `-bootstrap-stale-cache`: reads that snapshot in a new process, simulates a network timeout and reaches `degraded` without deleting the stale value.

No test targets are included. These scenarios are launchable manual acceptance fixtures.

The two cache scenarios must run in separate app processes. See [Cache and offline](CachingAndOffline.md) for the exact manual sequence.
