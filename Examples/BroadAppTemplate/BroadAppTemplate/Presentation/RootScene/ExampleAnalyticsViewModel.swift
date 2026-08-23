import BroadMonetization
import Foundation

@MainActor
final class ExampleAnalyticsViewModel: ObservableObject {
    @Published private(set) var events: [ExampleRecordedMonetizationEvent] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var isClearing = false
    @Published private(set) var lastUpdatedAt: Date?
    @Published private(set) var lastClearedEventCount: Int?

    private let recorder: ExampleRecordingMonetizationAnalytics
    private var observationTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?

    init(recorder: ExampleRecordingMonetizationAnalytics) {
        self.recorder = recorder
    }

    deinit {
        observationTask?.cancel()
        refreshTask?.cancel()
        resetTask?.cancel()
    }

    func startObserving() {
        guard observationTask == nil else {
            return
        }

        let recorder = recorder
        observationTask = Task { @MainActor [weak self, recorder] in
            let updates = await recorder.updates()
            for await snapshot in updates {
                guard let self, !Task.isCancelled else {
                    return
                }
                apply(snapshot)
            }
        }
    }

    func refresh() async {
        requestRefresh()
        await refreshTask?.value
    }

    func requestRefresh() {
        guard refreshTask == nil else {
            return
        }

        isRefreshing = true
        let recorder = recorder
        refreshTask = Task { @MainActor [weak self, recorder] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            let snapshot = await recorder.snapshot()
            guard let self, !Task.isCancelled else {
                return
            }
            refreshTask = nil
            isRefreshing = false
            apply(snapshot)
        }
    }

    func reset() async {
        requestReset()
        await resetTask?.value
    }

    func requestReset() {
        guard resetTask == nil, !events.isEmpty else {
            return
        }

        isClearing = true
        lastClearedEventCount = nil
        let recorder = recorder
        resetTask = Task { @MainActor [weak self, recorder] in
            let count = await recorder.reset()
            guard let self, !Task.isCancelled else {
                return
            }
            resetTask = nil
            isClearing = false
            lastClearedEventCount = count
            apply([])
        }
    }

    private func apply(
        _ snapshot: [ExampleRecordedMonetizationEvent]
    ) {
        events = snapshot
        lastUpdatedAt = Date()
    }
}

extension MonetizationAnalyticsEvent {
    var exampleName: String {
        switch self {
        case .paywallLoadStarted: "paywall_load_started"
        case .paywallLoadSuccess: "paywall_load_success"
        case .paywallLoadFailed: "paywall_load_failed"
        case .paywallShown: "paywall_shown"
        case .paywallClosed: "paywall_closed"
        case .productSelected: "product_selected"
        case .purchaseStarted: "purchase_started"
        case .purchaseSuccess: "purchase_success"
        case .purchaseCompletedButUnverified: "purchase_completed_unverified"
        case .purchaseCancelled: "purchase_cancelled"
        case .purchasePending: "purchase_pending"
        case .purchaseFailed: "purchase_failed"
        case .restoreStarted: "restore_started"
        case .restoreSuccess: "restore_success"
        case .restoreNothingFound: "restore_nothing_found"
        case .restoreUnavailable: "restore_unavailable"
        case .entitlementResolved: "entitlement_resolved"
        case .ruCheckoutCreated: "ru_checkout_created"
        case .ruCheckoutOpenFailed: "ru_checkout_open_failed"
        case .ruCheckoutSafariReturned: "ru_checkout_safari_returned"
        case .ruCheckoutConfirmed: "ru_checkout_confirmed"
        case .ruCheckoutTimedOut: "ru_checkout_timed_out"
        }
    }

    var exampleSummary: String {
        switch self {
        case let .paywallLoadStarted(context):
            Self.loadSummary(context)
        case let .paywallLoadSuccess(_, paywall):
            Self.paywallSummary(paywall)
        case let .paywallLoadFailed(context, failure):
            "attempt=\(context.attemptID.rawValue) · \(Self.failureSummary(failure))"
        case let .paywallShown(paywall):
            Self.paywallSummary(paywall)
        case let .paywallClosed(paywall, reason):
            "\(Self.paywallSummary(paywall)) · reason=\(reason.rawValue)"
        case let .productSelected(paywall, product):
            "\(Self.paywallSummary(paywall)) · sku=\(product.productID.rawValue)"
        case let .purchaseStarted(context),
             let .purchaseSuccess(context),
             let .purchaseCompletedButUnverified(context),
             let .purchaseCancelled(context),
             let .purchasePending(context):
            Self.purchaseSummary(context)
        case let .purchaseFailed(context, failure):
            "\(Self.purchaseSummary(context)) · \(Self.failureSummary(failure))"
        case let .restoreStarted(context),
             let .restoreSuccess(context),
             let .restoreNothingFound(context):
            "attempt=\(context.attemptID.rawValue)"
        case let .restoreUnavailable(context, failure):
            "attempt=\(context.attemptID.rawValue) · \(Self.failureSummary(failure))"
        case let .entitlementResolved(context):
            Self.entitlementSummary(context)
        case let .ruCheckoutCreated(context),
             let .ruCheckoutSafariReturned(context),
             let .ruCheckoutConfirmed(context),
             let .ruCheckoutTimedOut(context):
            Self.ruSummary(context)
        case let .ruCheckoutOpenFailed(context, failure):
            "\(Self.ruSummary(context)) · \(Self.failureSummary(failure))"
        }
    }
}

private extension MonetizationAnalyticsEvent {
    static func loadSummary(
        _ context: PaywallLoadAnalyticsContext
    ) -> String {
        [
            "attempt=\(context.attemptID.rawValue)",
            "requested=\(context.requestedPlacementID.rawValue)",
            "fallback=\(context.fallbackPlacementID.rawValue)"
        ].joined(separator: " · ")
    }

    static func paywallSummary(
        _ context: PaywallAnalyticsContext
    ) -> String {
        let variation = context.variationID?.rawValue ?? "none"
        return [
            "presentation=\(context.presentationID.rawValue)",
            "requested=\(context.requestedPlacementID.rawValue)",
            "resolved=\(context.resolvedPlacementID.rawValue)",
            "variation=\(variation)"
        ].joined(separator: " · ")
    }

    static func purchaseSummary(
        _ context: PurchaseAnalyticsContext
    ) -> String {
        let variation = context.paywallVariationID?.rawValue ?? "none"
        return [
            "attempt=\(context.attemptID.rawValue)",
            "sku=\(context.productID.rawValue)",
            "method=\(context.checkoutMethod.rawValue)",
            "variation=\(variation)"
        ].joined(separator: " · ")
    }

    static func entitlementSummary(
        _ context: EntitlementAnalyticsContext
    ) -> String {
        [
            "attempt=\(context.attemptID.rawValue)",
            "state=\(stateName(context.state))",
            "freshness=\(freshnessName(context.freshness))",
            "sources=\(context.sources.count)"
        ].joined(separator: " · ")
    }

    static func ruSummary(
        _ context: RUCheckoutAnalyticsContext
    ) -> String {
        let variation = context.paywallVariationID?.rawValue ?? "none"
        return [
            "attempt=\(context.attemptID.rawValue)",
            "product=\(context.productID.rawValue)",
            "method=\(context.checkoutMethod.rawValue)",
            "variation=\(variation)"
        ].joined(separator: " · ")
    }

    static func failureSummary(
        _ failure: MonetizationAnalyticsFailure
    ) -> String {
        "error=\(failure.kind.rawValue)/\(failure.diagnosticCode)"
    }

    static func stateName(_ state: EntitlementState) -> String {
        switch state {
        case .active: "active"
        case .inactive: "inactive"
        case .unresolved: "unresolved"
        }
    }

    static func freshnessName(_ freshness: EntitlementFreshness) -> String {
        switch freshness {
        case .refreshed: "refreshed"
        case .cached: "cached"
        case .grace: "grace"
        case .unresolved: "unresolved"
        }
    }
}
