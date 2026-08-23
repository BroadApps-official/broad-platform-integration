#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_roots=(
    "$platform_root/Sources"
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate"
)
violation_count=0

run_check() {
    local description="$1"
    local pattern="$2"
    shift 2

    local output
    local status=0
    output="$(rg -n "$@" "$pattern" "${source_roots[@]}")" || status=$?

    case "$status" in
        0)
            echo "$description"
            echo "$output"
            violation_count=$((violation_count + 1))
            ;;
        1)
            ;;
        *)
            echo "Architecture check could not run: $description"
            exit "$status"
            ;;
    esac
}

run_canonical_file_check() {
    local description="$1"
    local pattern="$2"
    local allowed_file="$3"
    local matches
    local filtered_output=""
    local status=0

    matches="$(rg -n --glob '**/*.swift' "$pattern" "${source_roots[@]}")" || status=$?

    case "$status" in
        0)
            while IFS= read -r match; do
                if [[ "$match" != "$allowed_file:"* ]]; then
                    filtered_output+="$match"$'\n'
                fi
            done <<< "$matches"

            if [[ -n "$filtered_output" ]]; then
                echo "$description"
                echo "${filtered_output%$'\n'}"
                violation_count=$((violation_count + 1))
            fi
            ;;
        1)
            ;;
        *)
            echo "Architecture check could not run: $description"
            exit "$status"
            ;;
    esac
}

require_file_pattern() {
    local description="$1"
    local file="$2"
    local pattern="$3"
    local status=0

    # Some required contracts intentionally span several formatted Swift lines.
    # Multiline mode keeps these checks stable after SwiftFormat rewrites layout.
    rg -q --pcre2 --multiline "$pattern" "$file" || status=$?

    case "$status" in
        0)
            ;;
        1)
            echo "$description"
            echo "$file"
            violation_count=$((violation_count + 1))
            ;;
        *)
            echo "Architecture check could not run: $description"
            exit "$status"
            ;;
    esac
}

run_check \
    "Domain/Data must not import SwiftUI:" \
    '^[[:space:]]*import[[:space:]]+SwiftUI' \
    --glob '**/Domain/**/*.swift' \
    --glob '**/Data/**/*.swift'

run_check \
    "Domain must not import UI, tracking, commerce or vendor SDK frameworks:" \
    '^[[:space:]]*import[[:space:]]+(Adapty|AppKit|AppTrackingTransparency|StoreKit|StoreKitTest|SwiftUI|UIKit|WebKit)' \
    --glob '**/Domain/**/*.swift'

run_check \
    "BroadCore must not depend on higher-level platform modules:" \
    '^[[:space:]]*import[[:space:]]+(BroadMonetization|BroadUIFlows)' \
    --glob '**/BroadCore/**/*.swift'

run_check \
    "BroadMonetization must not depend on BroadUIFlows:" \
    '^[[:space:]]*import[[:space:]]+BroadUIFlows' \
    --glob '**/BroadMonetization/**/*.swift'

run_check \
    "Presentation must not import Adapty or StoreKit:" \
    '^[[:space:]]*import[[:space:]]+(Adapty|StoreKit)' \
    --glob '**/Presentation/**/*.swift'

run_check \
    "Views must not resolve dependencies:" \
    'resolver\.resolve[[:space:]]*\(' \
    --glob '**/*View*.swift'

run_check \
    "View extension files must not resolve dependencies:" \
    '(?s)\bextension[[:space:]]+[A-Za-z_][A-Za-z0-9_.]*View\b.*resolver\.resolve[[:space:]]*\(' \
    --pcre2 \
    --multiline \
    --glob '**/*.swift'

run_check \
    "System fonts must be defined only inside token files:" \
    '\.system[[:space:]]*\(' \
    --glob '**/*.swift' \
    --glob '!**/*Tokens.swift'

run_check \
    "View frame dimensions must come from tokens instead of numeric literals:" \
    '(?s)\.frame\([^)]{0,180}\b(width|height|minWidth|maxWidth|minHeight|maxHeight):[[:space:]]*[1-9][0-9]*(\.[0-9]+)?\b' \
    --pcre2 \
    --multiline \
    --glob '**/Presentation/**/*.swift'

run_check \
    "Onboarding must not contain Rate Us or review requests:" \
    '(?i)\b(rate[[:space:]_-]*us|request[[:space:]_-]*review|review|SKStoreReviewController|AppStore\.requestReview|\x{043e}\x{0446}\x{0435}\x{043d}\x{0438}\x{0442}\x{044c}|\x{043e}\x{0442}\x{0437}\x{044b}\x{0432})\b' \
    --pcre2 \
    --glob '**/Onboarding*/**/*.swift' \
    --glob '**/Onboarding*/**/*.strings' \
    --glob '**/Onboarding*/**/*.xcstrings' \
    --glob '**/Onboarding*/**/*.json' \
    --glob '**/Onboarding*/**/*.plist'

run_check \
    "Native review APIs must stay inside a dedicated ReviewAdapter:" \
    '(requestReview[[:space:]]*\(|SKStoreReviewController|AppStore\.requestReview)' \
    --glob '**/*.swift' \
    --glob '!**/*ReviewAdapter.swift'

run_canonical_file_check \
    "AppTrackingTransparency APIs must stay inside TrackingAuthorizationAdapter:" \
    '\b(AppTrackingTransparency|ATTrackingManager)\b' \
    "$platform_root/Sources/BroadCore/Infrastructure/Tracking/TrackingAuthorizationAdapter.swift"

run_canonical_file_check \
    "Preference APIs must stay inside the canonical UserDefaultsKeyValueStore:" \
    '\b(UserDefaults|NSUserDefaults|CFPreferences[A-Za-z]*)\b' \
    "$platform_root/Sources/BroadCore/Infrastructure/Persistence/UserDefaultsKeyValueStore.swift"

run_check \
    "Console output is forbidden; use BroadLoggerProtocol:" \
    '(^|[^A-Za-z0-9_.])((Swift\.)?(print|debugPrint|dump)|NSLog|NSLogv|CFShow)[[:space:]]*\(|\bFileHandle\.(standardOutput|standardError)\b' \
    --glob '**/*.swift'

run_check \
    "Legacy os_log and signpost APIs are forbidden:" \
    '\b(os_log|os_logv|os_signpost|OSSignposter)\b' \
    --glob '**/*.swift'

run_canonical_file_check \
    "OSLog APIs must stay inside the canonical OSLogBroadLogger:" \
    '(^[[:space:]]*(@[A-Za-z_][A-Za-z0-9_]*(\([^)]*\))?[[:space:]]+)*import([[:space:]]+(class|enum|func|struct|protocol|typealias|var|let))?[[:space:]]+(OSLog|os)(\.|[[:space:]]*$)|\bOSLog\.[A-Za-z_][A-Za-z0-9_]*\b|\bos\.(Logger|OSLog[A-Za-z0-9_]*|OSSignpost[A-Za-z0-9_]*)\b)' \
    "$platform_root/Sources/BroadCore/Infrastructure/Logging/OSLogBroadLogger.swift"

run_check \
    "Raw error descriptions are forbidden at platform boundaries:" \
    '(\.localizedDescription\b|String[[:space:]]*\([[:space:]]*describing:[[:space:]]*error\b)' \
    --glob '**/*.swift'

run_check \
    "Paywall UI must not contain hardcoded prices:" \
    '(?i)["\x27][^"\x27\r\n]{0,80}((\$|€|£|₽|USD|EUR|RUB)[[:space:]]*[0-9]|[0-9][[:space:]]*(€|£|₽|USD|EUR|RUB))' \
    --pcre2 \
    --glob '**/Paywall*/**/*.swift'

run_check \
    "Paywall UI must not contain hardcoded product identifiers:" \
    '(?i)(weekly|monthly|yearly|lifetime)[._-][A-Za-z0-9._-]+' \
    --glob '**/Paywall*/**/*.swift'

run_check \
    "Adapty paywall products must not be filtered, compacted, sorted or truncated:" \
    '(?s)\b(adaptyProducts|mappedProducts|paywallProducts|products)\b.{0,120}\.(filter|compactMap|sorted|prefix|suffix|dropFirst|dropLast)[[:space:]]*\(' \
    --pcre2 \
    --multiline \
    --glob '**/Data/Adapty/**/*.swift' \
    --glob '**/Infrastructure/Adapty/**/*.swift' \
    --glob '**/Domain/Paywalls/**/*.swift' \
    --glob '**/Application/Paywalls/**/*.swift' \
    --glob '**/Presentation/Paywall/**/*.swift'

run_check \
    "Adapty product arrays must not be rejected as a whole by per-product validation:" \
    '\bproducts\.allSatisfy[[:space:]]*\(' \
    --glob '**/Data/Adapty/AdaptyPaywallRepository+ProductMapping.swift'

run_check \
    "Paywall product and primary actions must not react with opacity, scale or pressed effects:" \
    '(configuration\.isPressed|\.(opacity|scaleEffect|brightness|contrast|saturation|blur)[[:space:]]*\()' \
    --pcre2 \
    --glob '**/BroadNoPressEffectButtonStyle.swift' \
    --glob '**/BroadSelectableProductRow.swift' \
    --glob '**/BroadPaywallPrimaryButton.swift'

run_check \
    "BroadAppTemplate must not replace its analytics fixture with a no-op destination:" \
    'NoOpMonetizationAnalytics' \
    --glob '**/ExampleMonetizationEnvironment.swift'

require_file_pattern \
    "Paywall product rows must use BroadNoPressEffectButtonStyle:" \
    "$platform_root/Sources/BroadUIFlows/Presentation/Paywall/BroadSelectableProductRow.swift" \
    '\.buttonStyle\([[:space:]]*BroadNoPressEffectButtonStyle\(\)[[:space:]]*\)'

require_file_pattern \
    "Paywall primary actions must use BroadNoPressEffectButtonStyle:" \
    "$platform_root/Sources/BroadUIFlows/Presentation/Paywall/BroadPaywallPrimaryButton.swift" \
    '\.buttonStyle\([[:space:]]*BroadNoPressEffectButtonStyle\(\)[[:space:]]*\)'

require_file_pattern \
    "Shared in-flight action button must show a ProgressView:" \
    "$platform_root/Sources/BroadUIFlows/Presentation/Loadable/BroadActionButton.swift" \
    '(?s)configuration\.isInFlight.{0,180}ProgressView\([[:space:]]*\)'

require_file_pattern \
    "Debug Keychain cleaner must stay behind DEBUG compilation:" \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Infrastructure/Security/DebugKeychainCleaner.swift" \
    '(?s)^#if[[:space:]]+DEBUG.*actor[[:space:]]+DebugKeychainCleaner'

require_file_pattern \
    "Debug Keychain deletion must be scoped by exact service:" \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Infrastructure/Security/DebugKeychainCleaner.swift" \
    'kSecAttrService[[:space:]]+as[[:space:]]+String:[[:space:]]+scope\.service'

require_file_pattern \
    "Invalid ATT delays must fail closed instead of crashing or requesting immediately:" \
    "$platform_root/Sources/BroadUIFlows/Domain/Onboarding/OnboardingTrackingAuthorizationPolicy.swift" \
    'guard[[:space:]]+delay[[:space:]]*>[[:space:]]*\.zero[[:space:]]+else'

require_file_pattern \
    "ATT must revalidate current window visibility after its delay:" \
    "$platform_root/Sources/BroadUIFlows/Presentation/Onboarding/OnboardingViewModel.swift" \
    'validateCurrentWindowVisibility\?\(\)[[:space:]]*==[[:space:]]*true'

require_file_pattern \
    "ATT live window validation must require a foreground-active scene:" \
    "$platform_root/Sources/BroadUIFlows/Presentation/Onboarding/OnboardingWindowVisibilityView.swift" \
    'window\.windowScene\?\.activationState[[:space:]]*==[[:space:]]*\.foregroundActive'

require_file_pattern \
    "Interactive targets must share one unscaled 44-point minimum:" \
    "$platform_root/Sources/BroadUIFlows/Presentation/Shared/BroadInteractiveMetrics.swift" \
    'minimumHitDimension:[[:space:]]*CGFloat[[:space:]]*=[[:space:]]*44'

require_file_pattern \
    "Paywall product rows must include busy and durable-pending selection guards:" \
    "$platform_root/Sources/BroadUIFlows/Presentation/Paywall/BroadPaywallView+Content.swift" \
    'viewModel\.canSelectProducts'

require_file_pattern \
    "Malformed Adapty product IDs must use a bounded non-raw surrogate:" \
    "$platform_root/Sources/BroadMonetization/Data/Adapty/AdaptyPaywallRepository+ProductMapping.swift" \
    'adapty-opaque-unavailable-'

require_file_pattern \
    "Malformed Adapty product IDs must not authorize checkout with Money:" \
    "$platform_root/Sources/BroadMonetization/Data/Adapty/AdaptyPaywallRepository+ProductMapping.swift" \
    'price:[[:space:]]*hasValidatedVendorProductID[[:space:]]*\?[[:space:]]*money\(product\)[[:space:]]*:[[:space:]]*nil'

require_file_pattern \
    "Product selection analytics must preserve the catalog product ID:" \
    "$platform_root/Sources/BroadMonetization/Domain/Analytics/MonetizationAnalyticsEvent.swift" \
    'public[[:space:]]+let[[:space:]]+productID:[[:space:]]*ProductID'

require_file_pattern \
    "BroadAppTemplate analytics must fan out only after deduplication:" \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Infrastructure/Analytics/ExampleMonetizationAnalyticsAssembly.swift" \
    'destination:[[:space:]]*deduplicated'

require_file_pattern \
    "BroadAppTemplate analytics must include a composite destination:" \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Infrastructure/Analytics/ExampleMonetizationAnalyticsAssembly.swift" \
    'CompositeMonetizationAnalytics'

require_file_pattern \
    "Special Offer catalog must close a subscription paywall before resolving the offer:" \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Presentation/RootScene/ExampleSpecialOfferFixtureView.swift" \
    '(?s)ExampleSpecialOfferCatalogFlowView.*case[[:space:]]+[.]?subscriptionPaywall.*BroadPaywallView.*onClose:[[:space:]]*subscriptionPaywallClosed.*case[[:space:]]+[.]?resolvingOffer.*resolutionProgress.*case[[:space:]]+[.]?specialOffer.*ExampleSpecialOfferFixtureView\(.*resetForCatalogPresentation\(\).*func[[:space:]]+subscriptionPaywallClosed\(\).*resolveIfNeeded\(\)'

require_file_pattern \
    "Confirmed completion of the catalog subscription paywall must bypass Special Offer:" \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Presentation/RootScene/ExampleSpecialOfferFixtureView.swift" \
    '(?s)case[[:space:]]+[.]?subscriptionPaywall:.*BroadPaywallView\(.*onClose:[[:space:]]*subscriptionPaywallClosed,[[:space:]]*onCompleted:[[:space:]]*\{[[:space:]]*_[[:space:]]+in[[:space:]]+dismiss\(\)[[:space:]]*\}'

require_file_pattern \
    "Initial AppFlow must resolve Special Offer only after the first paywall closes:" \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Presentation/AppFlow/AppFlowSceneViewModel.swift" \
    '(?s)func[[:space:]]+paywallClosed\(\).*specialOfferViewModel\.resolveIfNeeded\(\).*activeSpecialOfferViewModel[[:space:]]*=[[:space:]]*specialOfferViewModel.*func[[:space:]]+specialOfferClosed\(\).*coordinator\.initialPaywallDismissed\(\)'

require_file_pattern \
    "Confirmed purchase or restore on the first paywall must bypass Special Offer:" \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Presentation/AppFlow/AppFlowSceneViewModel.swift" \
    '(?s)func[[:space:]]+paywallCompleted\(.*case[[:space:]]+[.]purchased,[[:space:]]+[.]restored:.*activeSpecialOfferViewModel[[:space:]]*=[[:space:]]*nil.*coordinator\.subscriptionDidBecomeActive\(\)'

require_file_pattern \
    "Special Offer catalog must use the shared process analytics recorder:" \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Application/AppCompositionRoot.swift" \
    '(?s)makeCatalogSpecialOfferViewModel\(.*analyticsRecorder:[[:space:]]*runtime\.monetizationEnvironment\.analyticsRecorder'

require_file_pattern \
    "Debug analytics refresh must show in-flight feedback:" \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Presentation/RootScene/ExampleDebugScenariosView.swift" \
    '(?s)analyticsViewModel\.requestRefresh\(\).*analyticsViewModel\.isRefreshing.*ProgressView\(\)'

require_file_pattern \
    "Live Adapty example must fail before StoreKit purchase by company policy:" \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Infrastructure/Monetization/ExampleLiveAdaptyServicesFactory.swift" \
    'example\.company-policy\.storekit-purchase-disabled'

require_file_pattern \
    "Live Adapty example must fail before StoreKit restore by company policy:" \
    "$platform_root/Examples/BroadAppTemplate/BroadAppTemplate/Infrastructure/Monetization/ExampleLiveAdaptyServicesFactory.swift" \
    'example\.company-policy\.storekit-restore-disabled'

require_file_pattern \
    "5013 Adapty configuration must be wired as a tracked build configuration:" \
    "$platform_root/Examples/BroadAppTemplate/project.yml" \
    'LiveAdapty5013:[[:space:]]+Configuration/Adapty5013\.xcconfig'

require_file_pattern \
    "5109Codex Adapty configuration must be wired as a tracked build configuration:" \
    "$platform_root/Examples/BroadAppTemplate/project.yml" \
    'LiveAdapty5109Codex:[[:space:]]+Configuration/Adapty5109Codex\.xcconfig'

require_file_pattern \
    "Fresh-install recovery must force a new entitlement generation:" \
    "$platform_root/Sources/BroadMonetization/Application/Recovery/RecoverCustomerAccessUseCase.swift" \
    'policy:[[:space:]]*\.startNewGeneration'

require_file_pattern \
    "Token recovery must remain a server-authoritative app boundary:" \
    "$platform_root/Sources/BroadMonetization/Application/Recovery/CustomerAccessRecoveryModels.swift" \
    'protocol[[:space:]]+RecoverTokenAccountUseCaseProtocol'

require_file_pattern \
    "Interrupted connections must be classified as offline:" \
    "$platform_root/Sources/BroadCore/Infrastructure/Networking/NetworkFailureClassifier.swift" \
    '\.networkConnectionLost'

require_file_pattern \
    "RU HTTP must fail with a bounded result instead of waiting indefinitely:" \
    "$platform_root/Sources/BroadMonetization/Infrastructure/RUBilling/RUBillingAuthenticatedHTTPClient.swift" \
    'waitsForConnectivity[[:space:]]*=[[:space:]]*false'

require_file_pattern \
    "RU polling must stop immediately on offline or timeout:" \
    "$platform_root/Sources/BroadMonetization/Application/RUBilling/RefreshRUPaymentUseCase.swift" \
    '(?s)error\.kind[[:space:]]*==[[:space:]]*\.offline.{0,100}error\.kind[[:space:]]*==[[:space:]]*\.timeout'

require_file_pattern \
    "Provider-managed payloads must authorize their own feature gates:" \
    "$platform_root/Sources/BroadMonetization/Domain/Paywalls/PaywallPayload.swift" \
    'case[[:space:]]+\.verifiedFreshRemote,[[:space:]]+\.providerCacheFallbackPossible:(?s:.*?)[[:space:]]+true'

require_file_pattern \
    "Platform-cache payloads must not authorize provider feature gates:" \
    "$platform_root/Sources/BroadMonetization/Domain/Paywalls/PaywallPayload.swift" \
    'case[[:space:]]+\.platformCache,[[:space:]]+\.legacyUnqualified:(?s:.*?)[[:space:]]+false'

if ((violation_count > 0)); then
    echo "Architecture checks failed: $violation_count rule group(s) found."
    exit 1
fi

echo "Architecture checks passed."
