import SwiftUI

struct ModuleCardView: View {
    let module: RootViewModel.ModuleItem

    var body: some View {
        HStack(spacing: AppTokens.Spacing.cardContent) {
            Image(systemName: module.systemImage)
                .font(AppTokens.Font.moduleIcon)
                .foregroundStyle(accentColor)
                .frame(width: AppTokens.Size.moduleIcon, height: AppTokens.Size.moduleIcon)
                .background(accentColor.opacity(AppTokens.Opacity.iconBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppTokens.Radius.icon))

            VStack(alignment: .leading, spacing: AppTokens.Spacing.tiny) {
                Text(module.title)
                    .font(AppTokens.Font.cardTitle)
                    .foregroundStyle(AppTokens.Color.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(AppTokens.Scale.minimumTitle)

                Text(module.detail)
                    .font(AppTokens.Font.badge)
                    .foregroundStyle(accentColor)

                Text(module.description)
                    .font(AppTokens.Font.caption)
                    .foregroundStyle(AppTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTokens.Spacing.cardPadding)
        .background(AppTokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTokens.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: AppTokens.Radius.card)
                .stroke(accentColor.opacity(AppTokens.Opacity.border), lineWidth: AppTokens.Border.thin)
        }
    }

    private var accentColor: Color {
        switch module.kind {
        case .core:
            AppTokens.Color.core
        case .monetization:
            AppTokens.Color.monetization
        case .uiFlows:
            AppTokens.Color.uiFlows
        }
    }
}
