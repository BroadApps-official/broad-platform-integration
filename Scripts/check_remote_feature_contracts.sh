#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failure_count=0

require_pattern() {
    local description="$1"
    local file="$2"
    local pattern="$3"
    local status=0

    rg -q --pcre2 --multiline "$pattern" "$file" || status=$?
    case "$status" in
        0)
            echo "PASS: $description"
            ;;
        1)
            echo "FAIL: $description"
            echo "      $file"
            failure_count=$((failure_count + 1))
            ;;
        *)
            echo "Remote feature contract check could not run: $description"
            exit "$status"
            ;;
    esac
}

forbid_pattern() {
    local description="$1"
    local pattern="$2"
    shift 2
    local output=""
    local status=0

    output="$(rg -n --pcre2 --multiline "$pattern" "$@")" || status=$?
    case "$status" in
        0)
            echo "FAIL: $description"
            echo "$output"
            failure_count=$((failure_count + 1))
            ;;
        1)
            echo "PASS: $description"
            ;;
        *)
            echo "Remote feature contract check could not run: $description"
            exit "$status"
            ;;
    esac
}

payload_file="$platform_root/Sources/BroadMonetization/Domain/Paywalls/PaywallPayload.swift"
configuration_file="$platform_root/Sources/BroadMonetization/Domain/Paywalls/RemotePaywallConfiguration.swift"
adapty_repository_file="$platform_root/Sources/BroadMonetization/Data/Adapty/AdaptyPaywallRepository.swift"
purchase_file="$platform_root/Sources/BroadMonetization/Data/Adapty/AdaptyPurchaseRepository.swift"
registry_file="$platform_root/Sources/BroadMonetization/Infrastructure/Adapty/AdaptyProductRegistry.swift"
load_file="$platform_root/Sources/BroadMonetization/Application/Paywalls/LoadPaywallUseCase.swift"
last_valid_file="$platform_root/Sources/BroadMonetization/Data/Paywalls/LastValidRemoteConfigurationStore.swift"
special_use_case_file="$platform_root/Sources/BroadMonetization/Application/SpecialOffers/ResolveSpecialOfferUseCase.swift"
special_resolution_file="$platform_root/Sources/BroadMonetization/Domain/SpecialOffers/SpecialOfferResolution.swift"
ru_gate_file="$platform_root/Sources/BroadMonetization/Application/RUBilling/RUBillingGate.swift"
ru_debug_override_file="$platform_root/Sources/BroadMonetization/Application/RUBilling/RUBillingDebugOverride.swift"
ru_resolution_file="$platform_root/Sources/BroadMonetization/Application/RUBilling/ResolveCheckoutMethodsUseCase.swift"
ru_composition_models_file="$platform_root/Sources/BroadMonetization/Application/DI/RUBillingCompositionModels.swift"
ru_composition_factory_file="$platform_root/Sources/BroadMonetization/Application/DI/RUBillingCompositionFactory.swift"
example_environment_file="$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Infrastructure/Monetization/ExampleMonetizationEnvironment.swift"
adapty_configuration_file="$platform_root/Sources/BroadMonetization/Infrastructure/Adapty/AdaptyPlatformConfiguration.swift"
adapty_activation_file="$platform_root/Sources/BroadMonetization/Infrastructure/Adapty/AdaptySDKActivationGate.swift"

echo "Remote Config feature-gate contract matrix"

require_pattern \
    "A current Adapty/provider payload may drive provider-managed feature gates" \
    "$payload_file" \
    'case[[:space:]]+\.verifiedFreshRemote,[[:space:]]+\.providerCacheFallbackPossible:(?s:.*?)[[:space:]]+true'

require_pattern \
    "A BroadMonetization cache or legacy payload cannot enable provider gates" \
    "$payload_file" \
    'case[[:space:]]+\.platformCache,[[:space:]]+\.legacyUnqualified:(?s:.*?)[[:space:]]+false'

require_pattern \
    "Adapty explicitly marks its payload as provider-managed" \
    "$adapty_repository_file" \
    'remoteConfigurationProvenance:[[:space:]]*\.providerCacheFallbackPossible'

require_pattern \
    "Remote configuration strips special_offer when provider authority is absent" \
    "$configuration_file" \
    'specialOffer:[[:space:]]*authorizesProviderFeatureGates[[:space:]]*\?[[:space:]]*specialOffer[[:space:]]*:[[:space:]]*nil'

require_pattern \
    "Remote configuration records the same authority for RU presentation" \
    "$configuration_file" \
    'authorizesRUBillingPresentation:[[:space:]]*authorizesProviderFeatureGates'

require_pattern \
    "Special-offer resolution checks provider-managed provenance" \
    "$special_use_case_file" \
    'remoteConfigurationProvenance\.authorizesProviderManagedFeatureGates'

require_pattern \
    "Special-offer presentation authorization repeats the provenance guard" \
    "$special_resolution_file" \
    'remoteConfigurationProvenance\.authorizesProviderManagedFeatureGates'

require_pattern \
    "RU Billing requires explicit ru_pay enabled plus provider authorization" \
    "$ru_gate_file" \
    'case[[:space:]]+\.enabled:(?s:.*?)guard[[:space:]]+remoteConfiguration\.authorizesRUBillingPresentation[[:space:]]+else'

require_pattern \
    "Explicit false remains a RU Billing kill switch" \
    "$ru_gate_file" \
    'case[[:space:]]+\.disabled:[[:space:]]*return[[:space:]]+\.remoteFlagDisabled'

require_pattern \
    "Malformed ru_pay remains fail-closed" \
    "$ru_gate_file" \
    'case[[:space:]]+\.invalid:[[:space:]]*return[[:space:]]+\.remoteFlagInvalid'

require_pattern \
    "Missing ru_pay remains fail-closed" \
    "$ru_gate_file" \
    'case[[:space:]]+\.absent:(?s:.*?)return[[:space:]]+\.remoteFlagAbsent'

require_pattern \
    "RU Billing exposes typed modes for custom-named Debug configurations" \
    "$ru_debug_override_file" \
    'case[[:space:]]+followAdapty(?s:.*?)case[[:space:]]+forceEnabled(?s:.*?)case[[:space:]]+forceDisabled'

require_pattern \
    "RU Billing production store rejects manual overrides by default" \
    "$ru_debug_override_file" \
    'allowsManualOverrides:[[:space:]]*Bool[[:space:]]*=[[:space:]]*false(?s:.*?)mode[[:space:]]*=[[:space:]]*allowsManualOverrides[[:space:]]*\?[[:space:]]*initialMode[[:space:]]*:[[:space:]]*\.followAdapty(?s:.*?)self\.mode[[:space:]]*=[[:space:]]*allowsManualOverrides[[:space:]]*\?[[:space:]]*mode[[:space:]]*:[[:space:]]*\.followAdapty'

require_pattern \
    "Host template unlocks RU Billing manual override only in DEBUG" \
    "$example_environment_file" \
    '#if[[:space:]]+DEBUG(?s:.*?)RUBillingDebugOverrideStore\(allowsManualOverrides:[[:space:]]*true\)(?s:.*?)#else(?s:.*?)RUBillingDebugOverrideStore\(\)(?s:.*?)#endif'

require_pattern \
    "RU Billing gate consumes the locked store before the Adapty decision" \
    "$ru_gate_file" \
    'switch[[:space:]]+debugOverrideStore\.currentMode(?s:.*?)case[[:space:]]+\.forceEnabled:(?s:.*?)case[[:space:]]+\.forceDisabled:(?s:.*?)switch[[:space:]]+remoteConfiguration\.ruBillingGateDecision'

require_pattern \
    "RU Billing logs the resolved availability reason without payload data" \
    "$ru_resolution_file" \
    '\.ruBillingAvailabilityEvaluated\([[:space:]]*reason:[[:space:]]*reason\.logValue,[[:space:]]*methodCount:[[:space:]]*methods\.count'

require_pattern \
    "RU Billing composition owns one shared Debug override store" \
    "$ru_composition_models_file" \
    'public[[:space:]]+let[[:space:]]+debugOverrideStore:[[:space:]]*RUBillingDebugOverrideStore'

require_pattern \
    "Method resolution and final checkout recheck share the Debug override" \
    "$ru_composition_factory_file" \
    'let[[:space:]]+gate[[:space:]]*=[[:space:]]*RUBillingGate\((?s:.*?)debugOverrideStore:[[:space:]]*dependencies\.debugOverrideStore(?s:.*?)ResolveCheckoutMethodsUseCase\((?s:.*?)debugOverrideStore:[[:space:]]*dependencies\.debugOverrideStore'

require_pattern \
    "Adapty configuration accepts only a typed local fallback file URL" \
    "$adapty_configuration_file" \
    'public[[:space:]]+let[[:space:]]+fallbackFileURL:[[:space:]]*URL\?(?s:.*?)\$0\.isFileURL[[:space:]]*&&[[:space:]]*\$0\.pathExtension\.lowercased\(\)[[:space:]]*==[[:space:]]*"json"'

require_pattern \
    "Dashboard-generated Adapty fallback is registered before SDK activation" \
    "$adapty_activation_file" \
    'Adapty\.setFallback\(fileURL:[[:space:]]*fallbackFileURL\)(?s:.*?)Adapty\.activate'

require_pattern \
    "Last-valid storage never resurrects old RU or special-offer gates" \
    "$last_valid_file" \
    'ruBillingGateDecision:[[:space:]]*parsed\.ruBillingGateDecision(?s:.*?)specialOffer:[[:space:]]*parsed\.specialOffer'

forbid_pattern \
    "Last-valid storage contains no previous RU/special gate fallback" \
    'previous\?\.(ruBillingGateDecision|isRUBillingEnabled|specialOffer)' \
    "$last_valid_file"

require_pattern \
    "A paywall restored from the platform cache is downgraded to platformCache" \
    "$load_file" \
    'catalogSource[[:space:]]*==[[:space:]]*\.cache(?s:.*?)\?[[:space:]]*\.platformCache'

require_pattern \
    "Fallback keeps requested and actually resolved placements" \
    "$load_file" \
    'requestedPlacementID:[[:space:]]*requestedPlacementID(?s:.*?)resolvedPlacementID:[[:space:]]*resolvedPlacementID'

require_pattern \
    "Adapty paywall loading keeps raw products in its internal registry" \
    "$adapty_repository_file" \
    'context\.productRegistry\.store\((?s:.*?)products:[[:space:]]*zip\(mappedProducts,[[:space:]]*adaptyProducts\)'

require_pattern \
    "Adapty purchase resolves the exact selected raw product from that registry" \
    "$purchase_file" \
    'context\.productRegistry\.product\(for:[[:space:]]*selection\)'

require_pattern \
    "The Adapty product registry stays internal to BroadMonetization" \
    "$registry_file" \
    '^actor[[:space:]]+AdaptyProductRegistry'

forbid_pattern \
    "The Adapty data layer contains no custom REST/URLSession transport" \
    '\b(URLSession|URLRequest|URLResponse|HTTPURLResponse)\b' \
    "$platform_root/Sources/BroadMonetization/Data/Adapty" \
    "$platform_root/Sources/BroadMonetization/Infrastructure/Adapty" \
    --glob '*.swift'

forbid_pattern \
    "The platform contains no second client-side experiment randomizer" \
    '(?i)\b(ExperimentAssignment|CohortAssignment|SegmentAssignment|ExperimentRandomizer|CohortRandomizer|ClientSideRandomizer|arc4random|randomElement)\b' \
    "$platform_root/Sources/BroadMonetization" \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate" \
    --glob '*.swift'

if ((failure_count > 0)); then
    echo "Remote Config feature-gate contract matrix failed: $failure_count item(s)."
    exit 1
fi

echo "Remote Config feature-gate contract matrix passed."
