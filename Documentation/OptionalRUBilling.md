# Optional RU billing in platform set 5

The base graph is `BroadUIFlows → BroadMonetization → BroadCore`.
`BroadExtensions` remains independent. RU-enabled apps explicitly add the separate
[broad-ru-billing-ios repository](https://github.com/BroadApps-official/broad-ru-billing-ios).
Its logic product is `BroadRUBilling`; standard SwiftUI screens are `BroadRUBillingUI`.
Neither base module depends on that repository.

| Application | Products | Example |
|---|---|---|
| App Store only | BroadCore 3.0.0, BroadMonetization 5.0.0, BroadUIFlows 5.0.0 | BroadAppleOnlyTemplate |
| App Store + RU | Base products + BroadRUBilling 1.0.0 + optional BroadRUBillingUI 1.0.0 | BroadAppTemplate |

Choose dependencies at build time. An app without RU billing has no disabled RU
service, RU callback URL, foreground poller or payment resources. A remote flag may
control presentation only after the provider is explicitly installed.

## Migration

Import the new module where RU types are used. Pass
`RemotePaywallConfigurationParser(providers: [RUBillingRemoteConfigurationParser()])`
to the Adapty factory. The optional RU factory supplies `paywallLoaderFactory`;
the experiment tracker supplies `viewReporting`. Use `RUBillingCheckoutAdapter`
as `additionalCheckout` and the same operation gate as Apple purchase/restore.
Use `BroadRUPaywallView` for RU presentation and keep its configuration separate
from `BroadPaywallConfiguration`. Base support email retains token balance and IDs;
the RU greeting extension lives in BroadRUBillingUI.

Register callback URLs, foreground handling and browser dismissal only in the
RU-enabled app composition. Route a validated app-owned return URL to
`applicationDidBecomeActive()` for authoritative reconciliation. Never infer payment
from a URL or browser dismissal. Use `RecoverRUCustomerAccessUseCase` for optional
subscription-management recovery alongside base entitlement/token recovery.

Keep application ID, account identity, cache repository and durable keys unchanged.
The new provider reads existing pending attempts with their old schema and raw
identifiers. Account-policy bounded waiting, late payments and stale callback
protection remain covered by the provider's executable probes.

## Validation

`bash Scripts/check_optional_billing.sh` builds a separate Apple-only graph in Debug
and unsigned Release and checks package resolution, Mach-O symbols and bundled
artifacts. `bash Scripts/agent_gate.sh` also builds the RU-enabled template and the
two existing compile-only Adapty configurations. No financial operation is executed.

While preparing a release set, `BROAD_PLATFORM_VERIFY_CANDIDATE=1` permits only pending
integration evidence. Module gate and CI evidence must already be passed. After the
candidate gate passes, record integration evidence and run the normal gate before release.
