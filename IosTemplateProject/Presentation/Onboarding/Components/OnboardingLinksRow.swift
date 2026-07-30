import SwiftUI

struct OnboardingLinksRow: View {
    let termsURL: URL
    let privacyURL: URL
    var restoreAction: (() -> Void)?

    var body: some View {
        HStack {
            linkButton(title: "Terms of Use") {
                UIApplication.shared.open(termsURL)
            }
            Spacer()
            if let restoreAction {
                linkButton(title: "Restore") {
                    restoreAction()
                }
                Spacer()
            }
            linkButton(title: "Privacy Policy") {
                UIApplication.shared.open(privacyURL)
            }
        }
    }

    private func linkButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.4)
        }
        .frame(maxWidth: .infinity)
    }
}
