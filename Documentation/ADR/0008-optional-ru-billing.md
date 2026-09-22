# Optional RU Billing package

Status: accepted and implemented in platform set 5.0.0.

Both module and integration gates passed. See [release evidence](../../AgentChecks/STATUS.md).

## Decision

`broad-ru-billing-ios` owns two products: `BroadRUBilling` (payment logic)
and `BroadRUBillingUI` (optional SwiftUI presentation). Neither BroadMonetization
nor BroadUIFlows depends on this repository. Apps opt in through their package
graph and composition root; disabling a remote feature flag is a different operation.

BroadMonetization owns provider-neutral checkout identifiers, entitlement sources,
the shared operation gate, paywall context, configuration extension points and
presentation reporting policy. RU catalog, HTTP clients, consent, account-policy
polling, durable pending state, experiment reporting and callback handling belong
to the optional package.

The existing persisted identifiers, storage keys and pending-payment wire format
must survive the move. Completion of local waiting never asserts financial
cancellation. Every provider shares the same operation gate and account epoch.
Remote configuration extensions retain current-placement precedence and never
revive authority from persistent cache.

## Acceptance

- Independent Apple-only graph builds without fetching or compiling the RU package.
- Apple-only app contains no RU symbols, resources, callback registration or routes.
- RU-enabled graph builds and retains checkout, return coalescing, recovery,
  cancellation, Special Offer, tokens and single-destination analytics contracts.
- Production contract probes exercise old durable data after the module move.
- Public APIs, DocC, examples, module gates, compatibility pins and documentation
  are updated together before a coordinated release.
