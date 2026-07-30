import SwiftUI

struct OnboardingNextButton: View {
    var title: String
    var isEnabled: Bool = true
    var useGradient: Bool = true
    var action: (() -> Void)?

    var body: some View {
        Button {
            guard isEnabled else { return }
            action?()
        } label: {
            ZStack {
                if useGradient {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.specialGreen, .specialDarkGreen],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(isEnabled ? 1 : 0.5)
                } else {
                    Capsule()
                        .fill(Color.specialGreen)
                        .opacity(isEnabled ? 1 : 0.5)
                }

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isEnabled ? Color.white : Color.white.opacity(0.36))
            }
        }
        .frame(height: 52)
        .disabled(!isEnabled)
    }
}
