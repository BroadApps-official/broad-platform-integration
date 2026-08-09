# RU billing

RU billing is an optional adapter chain. It is enabled only when three independent
conditions are true:

1. the host application enabled the feature;
2. verified-fresh remote decision is `.enabled`, or the decision is genuinely
   `.absent` and the host explicitly selected fallback `.enabled`;
3. the current App Store storefront code is `RU` or `RUS`.

The device region, application language and `Locale.current` never participate in
eligibility. `Locale(identifier: "ru_RU")` is used only by `RUBPriceFormatter` to
format an already loaded RUB price.

## Safe disabled composition

An application without RU billing does not create fake URLs, credentials or an
always-unresolved entitlement source:

```swift
let checkoutMethods: any ResolveCheckoutMethodsUseCaseProtocol =
    DisabledRUBillingCheckoutMethodsUseCase()
let startSelectedRU: any StartSelectedRUCheckoutUseCaseProtocol =
    DisabledSelectedRUCheckoutUseCase()

let catalog: any RUCatalogRepositoryProtocol = DisabledRUCatalogRepository()
let subscription: any RUSubscriptionRepositoryProtocol =
    DisabledRUSubscriptionRepository()
```

`BroadMonetizationServices` also supplies an Apple-only
`CheckoutSelectedProductUseCaseProtocol` by default. No RU assembly, endpoint or
fake catalog is needed for an App Store-only application.

Most importantly, do not add a `.ruBilling` `EntitlementSourceRegistration` when
the feature is disabled. The generic entitlement engine must contain only sources
that the application can authoritatively verify.

## Storefront and cache

`StoreKitCurrentStorefrontClient` reads `StoreKit.Storefront.current`.
`CachedStorefrontRepository` writes that verified result through the common
`CacheRepositoryProtocol`. `currentStorefront()` and
`liveCurrentStorefront()` are live-authoritative: when StoreKit cannot provide a
current value, eligibility resolves as unavailable. A previous Russian value is
never used to expose a payment method or create checkout after an account change.

`cachedStorefrontHint()` is a separate, explicitly non-authoritative API. A host
may use it for explanatory UI only; it must never feed `RUBillingGate`.

```swift
let storefrontRepository = CachedStorefrontRepository(
    cache: cache,
    cacheTimeToLive: 24 * 60 * 60
)
```

The default checkout gate is conservative:

```swift
let checkoutMethods = ResolveCheckoutMethodsUseCase(
    storefrontRepository: storefrontRepository,
    catalogRepository: catalogRepository,
    isFeatureEnabled: true,
    remoteGateFallback: .disabled
)
```

`RemoteRUBillingGateDecision` has four states: `.absent`, `.enabled`, `.disabled`,
`.invalid`. Parser scans every configured alias: all true → enabled; any false →
disabled; no false plus malformed/conflicting data → invalid; no aliases → absent.

With host fallback `.disabled`, absent never exposes an RU CTA. `.disabled` and
`.invalid` fail-closed under either fallback and any provenance. `.enabled`
requires `.verifiedFreshRemote`; provider-cache/platform-cache/legacy enabled
does not authorize billing and does not fall through to host fallback. Explicit
host fallback `.enabled` applies **only** to `.absent`.

## HTTP configuration and authorization

The package contains no production host, app identifier, endpoint path or token.
The host supplies all of them:

```swift
let configuration = RUBillingHTTPConfiguration(
    baseURL: URL(string: "https://payments.example.com")!,
    applicationID: AppIdentity.paymentApplicationID,
    appBundleIdentifier: AppIdentity.bundleIdentifier,
    endpoints: RUBillingEndpointConfiguration(
        catalog: RUBillingEndpointPath(rawValue: "/v1/catalog"),
        checkout: RUBillingEndpointPath(rawValue: "/v1/checkout"),
        paymentStatus: RUBillingEndpointPath(rawValue: "/v1/payment/status"),
        entitlementStatus: RUBillingEndpointPath(rawValue: "/v1/subscription/status"),
        cancellation: RUBillingEndpointPath(rawValue: "/v1/subscription/cancel")
    )
)
```

Every URL must use HTTPS. Redirects, URL credentials, cookies, URL cache and
unbounded responses are rejected. Authorization comes from the existing
`SubjectAuthorizationProviderProtocol`; its bearer value is subject-bound,
transient, redacted from reflection and never logged or persisted. Every
successful authenticated response is accepted only if the provider still returns
the exact same credential for the exact subject after the network suspension. A
logout, account switch or token rotation makes the old response unavailable.

## Enabled composition in two steps

`RUBillingCompositionFactory` builds the production adapters. The two-step API
avoids a dependency cycle: the RU registration is needed to construct the common
entitlement engine, while polling/cancel use cases need that completed engine.

```swift
// One instance is owned by the app for its whole process lifetime.
let authorizationSession = SubjectAuthorizationSession()
let authorizationBinding = authorizationSession.begin(for: entitlementSubject)

let ruFactory = RUBillingCompositionFactory(
    configuration: RUBillingCompositionConfiguration(
        http: configuration,
        entitlementFreshness: ruFreshnessPolicy,
        isFeatureEnabled: true
    ),
    dependencies: RUBillingCompositionDependencies(
        subject: entitlementSubject,
        applicationIdentifier: AppIdentity.bundleIdentifier,
        authorizationProvider: appSessionAuthorizationProvider,
        authorizationBinding: authorizationBinding,
        cache: cache,
        analytics: analytics,
        productMappingPolicy: ExactOnlyRUCatalogProductMappingPolicy()
    )
)

let ruRegistration = ruFactory.makeEntitlementRegistration()

let entitlementEngine = EntitlementEngine(
    registrations: appleAndBackendRegistrations + [ruRegistration],
    subject: entitlementSubject,
    cache: entitlementCache,
    timeoutPolicy: entitlementTimeout
)

let ru = ruFactory.makeServices(
    refreshEntitlement: entitlementEngine,
    operationGate: monetizationServices.operationGate
)
```

Every replacement identity bundle calls `authorizationSession.begin(for:)` on
that same app-wide instance before it creates new dependencies. This atomically
invalidates bindings retained by old in-flight tasks, even if an old immutable
provider still returns its previous token. Logout without a replacement bundle
calls `authorizationSession.invalidate()`. A concurrent invalidation never traps:
the dependency keeps its structurally matching binding, while HTTP and checkout
boundaries reject it as no longer current.

The resulting `RUBillingServices` exposes two small bundles:

- `catalog.repository`, `catalog.resolveProduct`,
  `catalog.resolveCheckoutMethods`;
- `checkout.startSelectedProduct`, `checkout.applicationReturn`,
  `checkout.cancelSubscription`, `checkout.operationGate`.

Raw backend-session creation, payment-status polling and their repositories are
module-internal. A host cannot skip exact catalog matching, storefront/remote
eligibility, durable pending ownership or the subject check performed on return.

Passing `monetizationServices.operationGate` is mandatory. The host originally
created this gate once for the whole application process and reuses it across
login/logout compositions. RU checkout registers its app-wide pending-session
blocker there, so an opened or persisted RU attempt blocks a new Apple
purchase/restore, while an Apple operation blocks creation of an RU backend
session. Do not construct a second gate for RU or for a new identity.

`applicationIdentifier` is a stable non-PII identifier for this app (normally the
bundle identifier). Pending RU storage uses one key per application identifier,
while the record retains the originating `EntitlementSubject`. A newly composed
identity sees only an opaque app-wide blocker: it receives neither checkout
session nor attempt identifiers and cannot poll or clear another subject's
backend session. Even a caller that retained old identifiers cannot clear through
a store composed for a different subject.

Pass the bundle to `RUBillingAssembly(services:)` after
`BroadMonetizationAssembly` when the host uses the platform Swinject assemblies.
It replaces the Apple-only `CheckoutSelectedProductUseCaseProtocol` registration
with the provider-neutral Apple/RU router, and registers the narrow RU protocols
and lifecycle coordinators in container scope.

For a custom backend, pass `RUBillingWireAdapters` with only the five grouped
request/response pairs changed. For migrated status sources, pass additional
authoritative clients through `RUBillingCompositionDependencies`.

## Wire contracts

Endpoint paths and HTTP methods are configurable, and backend payloads remain at
the infrastructure boundary. The package exposes separate request/response
contracts for catalog, checkout, payment status, cancellation and entitlement.

`BroadAppsRUBillingWireContract` and `BroadAppsRUCatalogResponseDecoder` implement
the documented convenience schema. A backend with another schema replaces only
the relevant protocols, for example `RUCheckoutRequestEncoderProtocol` and
`RUCheckoutResponseDecoderProtocol`. It does not need to fork Domain or UI.

A custom checkout encoder may add a receipt email from a host-owned transient
provider. It should do so only after the user explicitly asks for a receipt. The
platform never stores or logs the encoded request body.

### BroadApps convenience schema

The following schema is the complete contract implemented by
`BroadAppsRUBillingWireContract` and `BroadAppsRUCatalogResponseDecoder`. All
requests are authenticated by the HTTP client with a transient subject-bound
authorization value. JSON keys use `snake_case`; dates are ISO-8601 strings with
or without fractional seconds. Endpoint paths remain host configuration.

#### Catalog

```http
GET <catalog-path>?app_id=<application-id>&app_bundle=<bundle-id>
```

The preferred response wraps products in `products`:

```json
{
  "products": [
    {
      "product_id": "<backend-product-id>",
      "kind": "subscription",
      "app_store_product_id": "<apple-sku>",
      "price": {
        "amount": 499,
        "currency_code": "RUB"
      },
      "display_price": "499 ₽",
      "subscription_period": {
        "unit": "month",
        "count": 1
      },
      "payment_methods": ["sbp", "card"]
    }
  ]
}
```

The decoder also accepts a top-level array or partitioned object:

```json
{
  "subscriptions": [],
  "tokens": [],
  "coupons": []
}
```

Partition names force the corresponding kind. In a flat response `kind` accepts
`subscription`, `tokens`, `coupon` and `unknown`; an absent kind becomes
`unknown`. `app_store_product_id`, `price`, `display_price` and
`subscription_period` are optional. Supported period units are `day`, `week`,
`month`, `year` or a non-empty custom unit. Unknown payment-method strings are
ignored; the built-in generic premium checkout understands only `sbp` and
`card`.

#### Create checkout

```http
POST <checkout-path>
Content-Type: application/json
```

```json
{
  "product_id": "<backend-product-id>",
  "payment_method": "sbp",
  "accepts_auto_renewal": true,
  "app_id": "<application-id>",
  "app_bundle": "<bundle-id>"
}
```

```json
{
  "checkout_session_id": "<opaque-session-id>",
  "payment_url": "<ephemeral-https-payment-url>",
  "expires_at": "2030-01-02T03:04:05Z"
}
```

`payment_method` is `sbp` or `card`. `expires_at` is optional. The response is
rejected unless the session ID is valid and `payment_url` is HTTPS with a host
and without embedded URL credentials. The URL remains memory-only and is never
written into pending cache.

#### Payment status

```http
POST <payment-status-path>
Content-Type: application/json
```

```json
{
  "checkout_session_id": "<opaque-session-id>",
  "app_id": "<application-id>",
  "app_bundle": "<bundle-id>"
}
```

```json
{
  "checkout_session_id": "<opaque-session-id>",
  "status": "pending"
}
```

`status` accepts exactly `pending`, `paid`, `failed`, `cancelled` or `expired`.
The response session ID must equal the requested ID. Even `paid` does not grant
access directly: it only starts the common authoritative entitlement refresh.

#### Cancellation

```http
POST <cancellation-path>
Content-Type: application/json
```

```json
{
  "subscription_id": "<backend-subscription-id>",
  "app_id": "<application-id>",
  "app_bundle": "<bundle-id>"
}
```

```json
{
  "status": "cancelled",
  "effective_until": "2030-01-02T03:04:05Z"
}
```

`status` accepts `cancelled`, `already_inactive` or `failed`;
`effective_until` is optional. The optional legacy endpoint uses this same wire
shape and is called only when the host explicitly enables legacy fallback.

#### Entitlement

```http
GET <entitlement-status-path>?app_id=<application-id>&app_bundle=<bundle-id>
```

```json
{
  "subscription_active": true,
  "subscription_expires_at": "2030-01-02T03:04:05Z",
  "subscription_lifetime": false
}
```

`subscription_expires_at` and `subscription_lifetime` are optional; an absent
lifetime flag is `false`. Subject identity is never accepted from this JSON: it
comes from the authenticated composition and is attached locally after decode.
Network, authorization, type, date or consistency failures stay unresolved.

Do not silently change these payloads on one side. A backend with a different
shape must inject the matching encoder/decoder protocol pair and document that
app-owned contract separately.

## Catalog and matching

Every catalog row has an explicit `RUCatalogProductKind`:

- `subscription`;
- `tokens`;
- `coupon`;
- `unknown`.

`RUCatalogSections` keeps the categories separate. `RUCatalogProductMatcher`
uses this deterministic order:

1. exact case-sensitive match against backend product ID or mapped App Store ID;
2. an exact backend ID returned by an explicitly injected app-owned
   `RUCatalogProductMappingPolicyProtocol`;
3. the first row in backend order wins when several exact rows match.

`ExactOnlyRUCatalogProductMappingPolicy` is the default. The platform never maps
by period or price and never sends a guessed server ID. An application that owns
an explicit SKU-to-backend-ID table may inject
`AppOwnedRUCatalogProductMappingPolicy`; a custom period policy is also possible,
but it is entirely host-owned and opt-in.

The generic premium paywall exposes RU methods only for auto-renewing,
non-renewing and non-consumable entitlement products matched to a
`subscription` catalog row. Consumables, token packs, coupons and unknown
products are deliberately excluded because `RefreshRUPaymentUseCase` is a
premium-entitlement authority, not a token/coupon fulfillment authority. The
catalog taxonomy and read-only catalog boundary remain public so an app can build
a separate typed token fulfillment flow. Raw premium-session creation and status
polling remain internal and cannot be reused as a token-crediting shortcut.

`CachedRUCatalogRepository` keeps the last valid catalog for a finite configured
stale window. A partial network failure does not overwrite it. `RUBPriceFormatter`
formats valid `Money(currencyCode: "RUB")`; no price is invented in UI.

## Checkout, external page and pending context

The production chain is:

```text
create checkout -> validate HTTPS URL -> persist pending context -> open URL
                -> app becomes active -> poll -> authoritative entitlement refresh
```

`RUCheckoutFlowCoordinator` stores only the checkout session ID, an app-generated
attempt ID, catalog product ID, payment method, finite start date, optional backend
expiry, opaque originating-subject scope and safe paywall attribution
(`presentationID`, optional provider variation, requested/resolved placement).
That attribution remains local and survives cold launch so created/returned/
confirmed/timed-out app events describe the same paywall. It is never added to
`RUCheckoutRequest` or sent to the billing backend. The record does not store the
payment URL, email, bearer, raw provider payload or user identity.

`UIApplicationPaymentURLOpener` treats `UIApplication.open == false` as a failure.
An `.opened` flow outcome means only that the external page opened. It never grants
premium and never calls AppFlow activation.

The authenticated HTTP client revalidates the exact subject and exact credential
after the checkout response. The flow revalidates again before pending persistence
and once more after that `await`, immediately before opening Safari. If identity
changes before persistence, no external page opens. If it changes while persistence
is in flight, the old subject's durable blocker is deliberately retained and the
page still does not open; an uncertain financial attempt is never erased merely
because login state changed.

`CheckoutSelectedProductUseCaseProtocol` is the provider-neutral paywall
boundary. `.apple` delegates to the existing verified
`PurchaseSelectedProductUseCaseProtocol`. `.sbp` and `.card` delegate to
`StartSelectedRUCheckoutUseCase`, which resolves the exact selected occurrence to
an `RUCatalogProductID` and then starts `RUCheckoutFlowCoordinator`. `.opened` is
mapped to `.pending`, so presentation shows a notice and never emits completion.

The pending record is created with atomic insert-if-missing before the URL opens
and cleared with compare-and-remove for the exact session + attempt only. A
second identity/composition cannot inspect, overwrite or delete it. Storage
failure/corruption is `.unavailable` and remains a financial blocker. Cache TTL and
`expiresAt` compared with mutable device wall-clock time are only UI/review hints;
they never clear the blocker. Only a terminal backend result may clear it.

The coordinator checks the same `RUBillingGate` and a fresh
`StoreKit.Storefront.current` again immediately before creating checkout. Cached
storefront data cannot authorize it. The coordinator is single-flight and also
rejects a new start while a pending context exists, so concurrent taps cannot
create two backend sessions or overwrite the tracked attempt.

## Polling after return

The host calls `RUPaymentReturnCoordinator.applicationDidBecomeActive()` after an
actual transition back to active. The coordinator first verifies that the opaque
pending record belongs to its exact subject, then its internal polling use case
runs the configured number of attempts and delay. The host configures that policy
on the composition rather than receiving a raw session-polling service:

```swift
let ruConfiguration = RUBillingCompositionConfiguration(
    http: httpConfiguration,
    entitlementFreshness: entitlementFreshness,
    isFeatureEnabled: true,
    polling: RUPaymentPollingPolicy(
        maximumAttempts: 8,
        delay: .seconds(2)
    )
)
```

Each attempt first checks the exact checkout session status. Only `.paid` starts a
new unified entitlement generation. Pending, unavailable or mismatched status
cannot be confirmed by an unrelated pre-existing entitlement. The generation
checks all configured authorities, including primary backend and RU billing, and
only a refreshed authoritative `active` snapshot confirms purchase. A paid
payment without active entitlement remains pending; transport failure is
unavailable, not inactive.

Concurrent foreground callbacks join one in-flight operation for the same
attempt, so they cannot start duplicate polling loops or duplicate confirmation
analytics. The host still owns the lifecycle call and must pass `.active` to its
AppFlow coordinator; `.pending`, `.inactive` and `.unavailable` do not unlock UI.
RU app analytics preserves the original paywall variation and both logical
placements through this cold-launch path. Adapty does not automatically attribute
an external SBP/card payment; the host analytics destination owns that conversion
mapping and must treat the variation as opaque.
The return coordinator and paywall use the same `MonetizationOperationGate`.
After terminal `.active` or `.inactive`, the coordinator publishes a status change;
an already visible `PaywallViewModel` re-evaluates its CTA without relying on
SwiftUI `onAppear`.

## Cancellation and paid-through access

`URLSessionRUCancellationRepository` represents one endpoint.
`RUCancellationRepositoryFactory` reads
`RUBillingHTTPConfiguration.allowsLegacyCancellationFallback`. It composes
`FallbackRUSubscriptionRepository` only when that flag is `true` and an explicit
legacy path is supplied. There is no implicit legacy URL.

`CancelRUSubscriptionUseCase` refreshes the unified entitlement after a confirmed
cancellation. The cancellation itself does not revoke access immediately: a
server-authoritative RU status may remain active with `expiresAt` until the end of
the paid period.

## RU entitlement source

`URLSessionRUBillingEntitlementClient` accepts `active` or `inactive` only from a
successfully decoded current server response for the exact subject. Network,
authorization, decoding and contradictory date failures resolve as `unresolved`.

Several authoritative clients can be passed to `RUBillingEntitlementRepository`
for migrated identities or endpoints. Any confirmed active result wins. Inactive
is returned only when every configured client explicitly confirms inactive.

```swift
let ruRegistration = RUBillingEntitlementSourceFactory(
    clients: [ruEntitlementClient],
    authorizationBinding: authorizationBinding
).makeRegistration(
    configuration: RUBillingEntitlementSourceConfiguration(
        subject: entitlementSubject,
        freshnessPolicy: ruFreshnessPolicy
    )
)
```

This factory always creates exactly one logical `.ruBilling` registration. Add it
to `EntitlementEngine` only for an enabled, fully configured RU backend.

The RU cache record carries the binding's logical authorization epoch. Its
physical cache key uses one fixed authorization-session partition per
subject/source, so repeated login/logout does not create an unbounded number of
keys. A response or delayed write from a revoked bundle may only leave an
old-epoch record: a new binding rejects that record exactly and fails closed
instead of granting cached access.
