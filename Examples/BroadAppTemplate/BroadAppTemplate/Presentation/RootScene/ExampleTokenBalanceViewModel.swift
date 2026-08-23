import BroadCore
import BroadMonetization
import BroadUIFlows
import Foundation
import SwiftUI

@MainActor
final class ExampleTokenBalanceViewModel: ObservableObject {
    @Published private(set) var snapshot: TokenBalanceSnapshot?
    @Published private(set) var confirmedCallbackCount = 0

    private let logger: any BroadLoggerProtocol

    init(logger: any BroadLoggerProtocol = NoOpBroadLogger()) {
        self.logger = logger
    }

    func applyConfirmed(_ snapshot: TokenBalanceSnapshot) {
        self.snapshot = snapshot
        confirmedCallbackCount += 1
        logger.log(.tokenBalanceConfirmed)
    }

    var displayValue: String {
        guard let snapshot else {
            return "—"
        }
        return NSDecimalNumber(decimal: snapshot.balance).stringValue
    }
}

struct ExampleTokenBalanceButton: View {
    @ObservedObject var tokenPaywallViewModel: BroadTokenPaywallViewModel
    @ObservedObject var tokenBalanceViewModel: ExampleTokenBalanceViewModel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTokens.Spacing.small) {
                Image(systemName: "circle.grid.2x2.fill")
                    .font(AppTokens.Font.moduleIcon)
                    .foregroundStyle(AppTokens.Color.warning)

                VStack(alignment: .leading, spacing: AppTokens.Spacing.tiny) {
                    Text("Баланс токенов")
                        .font(AppTokens.Font.cardTitle)
                        .foregroundStyle(AppTokens.Color.primaryText)
                    Text(statusText)
                        .font(AppTokens.Font.caption)
                        .foregroundStyle(AppTokens.Color.secondaryText)
                }

                Spacer(minLength: 0)

                if tokenPaywallViewModel.isRecoveringAccountBalance {
                    ProgressView()
                        .tint(AppTokens.Color.warning)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppTokens.Color.warning)
                }
            }
            .padding(.horizontal, AppTokens.Spacing.screenHorizontal)
            .padding(.vertical, AppTokens.Spacing.small)
            .background(AppTokens.Color.surface)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("token-balance.open")
    }

    private var statusText: String {
        if tokenPaywallViewModel.isRecoveringAccountBalance {
            return "Сверяем с fixture-backend…"
        }
        return "\(tokenBalanceViewModel.displayValue) · открыть token paywall"
    }
}
