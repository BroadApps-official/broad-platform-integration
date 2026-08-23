import BroadCore
import BroadMonetization
import Foundation

public enum BroadTokenPaywallViewState: Equatable, Sendable {
    case idle
    case loading
    case content(PaywallPayload)
    case empty(PaywallPayload)
    case failure(AppError)

    public var payload: PaywallPayload? {
        switch self {
        case let .content(payload), let .empty(payload):
            payload
        case .idle, .loading, .failure:
            nil
        }
    }
}

public enum BroadTokenPaywallFeedback: Equatable, Sendable {
    case credited(TokenBalanceSnapshot)
    case pending
    case cancelled
    case recovered(TokenBalanceSnapshot)
    case failed(AppError)
}

public enum BroadTokenPaywallAnalyticsEvent: String, Equatable, Sendable {
    case loadStarted = "token_paywall_load_started"
    case loadSucceeded = "token_paywall_load_succeeded"
    case loadFailed = "token_paywall_load_failed"
    case productSelected = "token_product_selected"
    case purchaseStarted = "token_purchase_started"
    case purchaseCredited = "token_purchase_credited"
    case purchasePending = "token_purchase_pending"
    case purchaseCancelled = "token_purchase_cancelled"
    case purchaseFailed = "token_purchase_failed"
    case reconciliationStarted = "token_reconciliation_started"
    case balanceRecovered = "token_balance_recovered"
}

public struct BroadTokenPaywallAnalyticsRecord: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let event: BroadTokenPaywallAnalyticsEvent
    public let recordedAt: Date

    init(event: BroadTokenPaywallAnalyticsEvent, recordedAt: Date = Date()) {
        id = UUID()
        self.event = event
        self.recordedAt = recordedAt
    }
}
