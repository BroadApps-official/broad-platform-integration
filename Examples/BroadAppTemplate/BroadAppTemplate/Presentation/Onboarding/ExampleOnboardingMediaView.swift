import BroadUIFlows
import SwiftUI

struct ExampleOnboardingMediaView: View {
    let descriptor: OnboardingMediaDescriptor

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: AppTokens.Radius.hero,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            Circle()
                .fill(AppTokens.Color.primaryText.opacity(0.1))
                .frame(
                    width: AppTokens.Size.onboardingIcon,
                    height: AppTokens.Size.onboardingIcon
                )

            Image(systemName: systemImage)
                .font(AppTokens.Font.onboardingIcon)
                .foregroundStyle(AppTokens.Color.primaryText)
                .accessibilityHidden(true)
        }
        .frame(height: AppTokens.Size.onboardingMedia)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var systemImage: String {
        switch descriptor.identifier {
        case "foundation":
            "shippingbox.and.arrow.backward.fill"
        case "monetization":
            "rectangle.stack.fill"
        case "verified-access":
            "checkmark.shield.fill"
        default:
            "sparkles"
        }
    }

    private var gradientColors: [Color] {
        switch descriptor.identifier {
        case "foundation":
            [AppTokens.Color.core, AppTokens.Color.accent]
        case "monetization":
            [AppTokens.Color.monetization, AppTokens.Color.core]
        case "verified-access":
            [AppTokens.Color.uiFlows, AppTokens.Color.accent]
        default:
            [AppTokens.Color.accent, AppTokens.Color.core]
        }
    }

    private var accessibilityLabel: String {
        switch descriptor.identifier {
        case "foundation":
            "Shared platform foundation"
        case "monetization":
            "Adaptive product list"
        case "verified-access":
            "Verified premium access"
        default:
            "Platform illustration"
        }
    }
}
