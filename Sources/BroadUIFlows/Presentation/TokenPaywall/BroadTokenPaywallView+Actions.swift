import BroadMonetization
import Foundation
import SwiftUI

extension BroadTokenPaywallView {
    var primaryActionTitle: String {
        if viewModel.isRetrySuggested {
            return viewModel.isRecoveringPendingPurchase
                ? copy.actions.retryingTitle
                : copy.actions.retryTitle
        }
        return viewModel.isPurchaseInFlight
            ? copy.actions.purchasingTitle
            : copy.actions.purchaseTitle
    }

    var primaryActionIsEnabled: Bool {
        viewModel.isRetrySuggested
            ? !viewModel.isBusy
            : viewModel.canPurchase
    }

    func primaryAction() {
        if viewModel.isRetrySuggested {
            viewModel.retrySafely()
        } else {
            viewModel.purchaseSelectedProduct()
        }
    }

    var balanceText: String {
        guard let snapshot = viewModel.balanceSnapshot else {
            return "—"
        }
        return "\(NSDecimalNumber(decimal: snapshot.balance)) токенов"
    }

    func feedbackMessage(_ feedback: BroadTokenPaywallFeedback) -> String {
        switch feedback {
        case let .credited(snapshot):
            "\(copy.states.creditedMessage) Баланс: "
                + "\(NSDecimalNumber(decimal: snapshot.balance))."
        case .pending:
            copy.states.pendingMessage
        case .cancelled:
            copy.states.cancelledMessage
        case let .recovered(snapshot):
            "\(copy.states.recoveredMessage) Баланс: "
                + "\(NSDecimalNumber(decimal: snapshot.balance))."
        case let .failed(error):
            error.userMessage
        }
    }
}

extension MonetizationProduct {
    var isTokenPackage: Bool {
        kind == .consumable && price != nil
    }
}

extension BroadTokenPaywallFeedback {
    var systemImage: String {
        switch self {
        case .credited, .recovered:
            "checkmark.seal.fill"
        case .pending:
            "clock.badge.exclamationmark"
        case .cancelled:
            "xmark.circle"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    @MainActor
    func tint(theme: BroadPaywallTheme) -> Color {
        switch self {
        case .credited, .recovered:
            theme.palette.accent
        case .pending, .cancelled, .failed:
            theme.palette.secondaryText
        }
    }
}
