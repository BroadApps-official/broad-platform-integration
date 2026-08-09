import SwiftUI

struct BootstrapStatusCardView: View {
    let state: BootstrapStatusCardState
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppTokens.Spacing.cardContent) {
            indicator

            VStack(alignment: .leading, spacing: AppTokens.Spacing.tiny) {
                Text(title)
                    .font(AppTokens.Font.cardTitle)
                    .foregroundStyle(AppTokens.Color.primaryText)

                Text(message)
                    .font(AppTokens.Font.caption)
                    .foregroundStyle(AppTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if case let .failed(_, _, retryTitle) = state, let retryTitle {
                    Button(retryTitle, action: onRetry)
                        .font(AppTokens.Font.badge)
                        .buttonStyle(.borderedProminent)
                        .tint(AppTokens.Color.failure)
                        .padding(.top, AppTokens.Spacing.tiny)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppTokens.Spacing.cardPadding)
        .background(AppTokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTokens.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: AppTokens.Radius.card)
                .stroke(accent.opacity(AppTokens.Opacity.border), lineWidth: AppTokens.Border.thin)
        }
    }

    @ViewBuilder
    private var indicator: some View {
        switch state {
        case .loading:
            ProgressView()
                .tint(accent)
                .frame(width: AppTokens.Size.statusIcon, height: AppTokens.Size.statusIcon)
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .font(AppTokens.Font.statusIcon)
                .foregroundStyle(accent)
        case .degraded:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(AppTokens.Font.statusIcon)
                .foregroundStyle(accent)
        case .failed:
            Image(systemName: "xmark.octagon.fill")
                .font(AppTokens.Font.statusIcon)
                .foregroundStyle(accent)
        }
    }

    private var title: String {
        switch state {
        case let .loading(title, _),
             let .ready(title, _),
             let .degraded(title, _),
             let .failed(title, _, _):
            title
        }
    }

    private var message: String {
        switch state {
        case let .loading(_, message),
             let .ready(_, message),
             let .degraded(_, message),
             let .failed(_, message, _):
            message
        }
    }

    private var accent: Color {
        switch state {
        case .loading:
            AppTokens.Color.accent
        case .ready:
            AppTokens.Color.success
        case .degraded:
            AppTokens.Color.warning
        case .failed:
            AppTokens.Color.failure
        }
    }
}
