import BroadMonetization
import Foundation
import SwiftUI

@MainActor
struct BroadSpecialOfferMetadataView: View {
    let configuration: SpecialOfferRemoteConfiguration
    let countdownAuthorization: SpecialOfferCountdownAuthorization?
    let copy: BroadPaywallSpecialOfferCopy
    let theme: BroadPaywallTheme
    let locale: Locale

    var body: some View {
        if hasVisibleContent {
            VStack(spacing: theme.metrics.spacing.text) {
                if let badge = configuration.badge {
                    Text(badge)
                        .font(theme.typography.footer)
                        .foregroundStyle(theme.palette.actionForeground)
                        .padding(.horizontal, theme.metrics.spacing.productContent)
                        .padding(.vertical, theme.metrics.spacing.text)
                        .background(
                            Capsule(style: .continuous)
                                .fill(theme.palette.accent)
                        )
                }

                HStack(spacing: theme.metrics.spacing.productContent) {
                    crossedValue
                    multiplier
                }

                if let periodText = configuration.periodText {
                    Text(periodText)
                        .font(theme.typography.productDetail)
                        .foregroundStyle(theme.palette.secondaryText)
                        .multilineTextAlignment(.center)
                }

                countdown
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var crossedValue: some View {
        if let value = crossedValueText {
            Text(value)
                .font(theme.typography.productDetail)
                .foregroundStyle(theme.palette.secondaryText)
                .strikethrough(true)
                .accessibilityLabel(copy.crossedValueAccessibilityLabel)
                .accessibilityValue(value)
        }
    }

    @ViewBuilder
    private var multiplier: some View {
        if let value = configuration.priceMultiplier.flatMap(formattedDecimal) {
            Text("\u{00D7}\(value)")
                .font(theme.typography.productDetail)
                .foregroundStyle(theme.palette.accent)
                .accessibilityLabel(copy.multiplierAccessibilityLabel)
                .accessibilityValue(value)
        }
    }

    @ViewBuilder
    private var countdown: some View {
        if let countdownAuthorization {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let remaining = countdownAuthorization.remainingTimeInterval
                let value = Self.durationText(remaining)
                Text(value)
                    .font(theme.typography.productDetail)
                    .foregroundStyle(theme.palette.secondaryText)
                    .monospacedDigit()
                    .accessibilityLabel(copy.countdownAccessibilityLabel)
                    .accessibilityValue(value)
            }
        }
    }

    private var hasVisibleContent: Bool {
        configuration.badge != nil
            || crossedValueText != nil
            || configuration.priceMultiplier != nil
            || configuration.periodText != nil
            || countdownAuthorization != nil
    }

    private var crossedValueText: String? {
        configuration.crossedPrice
            ?? configuration.crossedValue.flatMap(formattedDecimal)
    }

    private func formattedDecimal(_ value: Decimal) -> String? {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        return formatter.string(from: value as NSDecimalNumber)
    }

    private static func durationText(_ interval: TimeInterval) -> String {
        guard interval.isFinite, interval > 0 else {
            return "00:00:00"
        }
        let boundedInterval = min(
            interval.rounded(.down),
            SpecialOfferDurationPolicy.maximumDuration
        )
        let seconds = Int(boundedInterval)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        return String(
            format: "%02d:%02d:%02d",
            hours,
            minutes,
            remainingSeconds
        )
    }
}
