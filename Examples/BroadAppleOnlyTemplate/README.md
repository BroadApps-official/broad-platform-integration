# Apple-only template

This fixture app links BroadCore 3.0.0, BroadMonetization 5.0.0 and BroadUIFlows 5.0.0.
It has its own package graph and contains no BroadRUBilling dependency, URL callback,
checkout polling, payment browser handler or RU resources. Use this composition for
an application that only needs App Store billing. The fixture never buys or restores.

For production, supply real Adapty configuration and base monetization services through
the application composition root. Use AppleCheckoutMethodsUseCase and the shared
operation gate; replace fixture repositories without adding RU disabled adapters.
The separate BroadAppTemplate demonstrates explicitly installed RU products.

Run `bash Scripts/check_optional_billing.sh` from the integration repository to build
and inspect this target and compare it with the RU-enabled package graph.
