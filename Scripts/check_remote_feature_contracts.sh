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
    "RU Billing requires explicit ru_pay enabled plus an authorized presentation" \
    "$ru_gate_file" \
    'case[[:space:]]+\.enabled:(?s:.*?)return[[:space:]]+remoteConfiguration\.authorizesRUBillingPresentation'

require_pattern \
    "Explicit false remains a RU Billing kill switch" \
    "$ru_gate_file" \
    'case[[:space:]]+\.disabled,[[:space:]]+\.invalid:(?s:.*?)return[[:space:]]+false'

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
