import BroadMonetization
import Foundation
import SwiftUI

public struct BroadRUSubscriptionManagementCopy: Equatable, Sendable {
    public let title: String
    public let currentPlanTitle: String
    public let fallbackPlanTitle: String
    public let activeTitle: String
    public let inactiveTitle: String
    public let activeUntilTitle: String
    public let autoRenewalOffTitle: String
    public let lifetimeTitle: String
    public let cancelTitle: String
    public let cancellingTitle: String
    public let cancelConfirmationTitle: String
    public let cancelConfirmationMessage: String
    public let keepTitle: String
    public let retryTitle: String
    public let loadingTitle: String

    public init(
        title: String,
        currentPlanTitle: String,
        fallbackPlanTitle: String,
        activeTitle: String,
        inactiveTitle: String,
        activeUntilTitle: String,
        autoRenewalOffTitle: String,
        lifetimeTitle: String,
        cancelTitle: String,
        cancellingTitle: String,
        cancelConfirmationTitle: String,
        cancelConfirmationMessage: String,
        keepTitle: String,
        retryTitle: String,
        loadingTitle: String
    ) {
        self.title = title
        self.currentPlanTitle = currentPlanTitle
        self.fallbackPlanTitle = fallbackPlanTitle
        self.activeTitle = activeTitle
        self.inactiveTitle = inactiveTitle
        self.activeUntilTitle = activeUntilTitle
        self.autoRenewalOffTitle = autoRenewalOffTitle
        self.lifetimeTitle = lifetimeTitle
        self.cancelTitle = cancelTitle
        self.cancellingTitle = cancellingTitle
        self.cancelConfirmationTitle = cancelConfirmationTitle
        self.cancelConfirmationMessage = cancelConfirmationMessage
        self.keepTitle = keepTitle
        self.retryTitle = retryTitle
        self.loadingTitle = loadingTitle
    }

    public static let russian = BroadRUSubscriptionManagementCopy(
        title: "Управление подпиской",
        currentPlanTitle: "Текущий тариф",
        fallbackPlanTitle: "Подписка",
        activeTitle: "Активна",
        inactiveTitle: "Неактивна",
        activeUntilTitle: "Доступ до",
        autoRenewalOffTitle: "Автопродление отключено",
        lifetimeTitle: "Бессрочный доступ",
        cancelTitle: "Отменить подписку",
        cancellingTitle: "Отменяем…",
        cancelConfirmationTitle: "Отменить подписку?",
        cancelConfirmationMessage:
        "Доступ сохранится до оплаченной даты, новых списаний не будет.",
        keepTitle: "Оставить подписку",
        retryTitle: "Повторить",
        loadingTitle: "Загружаем подписку"
    )
}

@MainActor
public struct BroadRUSubscriptionManagementView: View {
    @StateObject private var viewModel:
        BroadRUSubscriptionManagementViewModel
    @State private var showsCancellationConfirmation = false

    private let copy: BroadRUSubscriptionManagementCopy
    private let theme: BroadPaywallTheme

    public init(
        viewModel: BroadRUSubscriptionManagementViewModel,
        copy: BroadRUSubscriptionManagementCopy,
        theme: BroadPaywallTheme
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.copy = copy
        self.theme = theme
    }

    public init(
        viewModel: BroadRUSubscriptionManagementViewModel,
        copy: BroadRUSubscriptionManagementCopy = .russian
    ) {
        self.init(viewModel: viewModel, copy: copy, theme: .standard)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.metrics.spacing.content) {
                Text(copy.title)
                    .font(theme.typography.title)
                    .foregroundStyle(theme.palette.primaryText)

                content
            }
            .frame(maxWidth: theme.metrics.sizing.maximumContentWidth)
            .padding(theme.metrics.spacing.screen)
        }
        .background(theme.palette.background.ignoresSafeArea())
        .onAppear {
            viewModel.loadIfNeeded()
        }
        .confirmationDialog(
            copy.cancelConfirmationTitle,
            isPresented: $showsCancellationConfirmation,
            titleVisibility: .visible
        ) {
            Button(copy.cancelTitle, role: .destructive) {
                viewModel.cancelSubscription()
            }
            Button(copy.keepTitle, role: .cancel) {}
        } message: {
            Text(copy.cancelConfirmationMessage)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            HStack(spacing: theme.metrics.spacing.productContent) {
                ProgressView()
                Text(copy.loadingTitle)
                    .font(theme.typography.productDetail)
                    .foregroundStyle(theme.palette.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: minimumStateHeight)
        case let .failed(error):
            stateCard(
                title: error.userMessage,
                systemImage: "exclamationmark.triangle.fill"
            ) {
                actionButton(copy.retryTitle, isDestructive: false) {
                    viewModel.reload()
                }
            }
        case let .loaded(status):
            subscriptionCard(status)
        }
    }

    private func subscriptionCard(
        _ status: RUSubscriptionManagementStatus
    ) -> some View {
        VStack(alignment: .leading, spacing: theme.metrics.spacing.product) {
            planSummary(status)

            if status.isLifetime {
                Text(copy.lifetimeTitle)
                    .font(theme.typography.productDetail)
            } else if let expiresAt = status.expiresAt {
                Text("\(copy.activeUntilTitle): \(formattedDate(expiresAt))")
                    .font(theme.typography.productDetail)
                    .foregroundStyle(theme.palette.secondaryText)
            }

            if status.isAutoRenewalCancelled {
                Label(copy.autoRenewalOffTitle, systemImage: "calendar.badge.minus")
                    .font(theme.typography.productDetail)
                    .foregroundStyle(theme.palette.secondaryText)
            }

            if let error = viewModel.cancellationError {
                Text(error.userMessage)
                    .font(theme.typography.footer)
                    .foregroundStyle(.red)
            }

            if status.isActive,
               !status.isAutoRenewalCancelled,
               status.subscriptionID != nil {
                actionButton(
                    viewModel.isCancelling
                        ? copy.cancellingTitle
                        : copy.cancelTitle,
                    isDestructive: true
                ) {
                    showsCancellationConfirmation = true
                }
                .disabled(viewModel.isCancelling)
            }
        }
        .padding(theme.metrics.spacing.content)
        .background(
            RoundedRectangle(
                cornerRadius: theme.metrics.sizing.cornerRadius,
                style: .continuous
            )
            .fill(theme.palette.surface)
        )
    }

    @ViewBuilder
    private func planSummary(
        _ status: RUSubscriptionManagementStatus
    ) -> some View {
        Text(copy.currentPlanTitle)
            .font(theme.typography.productDetail)
            .foregroundStyle(theme.palette.secondaryText)

        Text(status.planName ?? copy.fallbackPlanTitle)
            .font(theme.typography.productTitle)
            .foregroundStyle(theme.palette.primaryText)

        Label(
            status.isActive ? copy.activeTitle : copy.inactiveTitle,
            systemImage: status.isActive
                ? "checkmark.circle.fill"
                : "minus.circle.fill"
        )
        .font(theme.typography.productDetail)
        .foregroundStyle(status.isActive ? Color.green : Color.secondary)
    }

    private func stateCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: theme.metrics.spacing.product) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(theme.palette.accent)
            Text(title)
                .font(theme.typography.productDetail)
                .multilineTextAlignment(.center)
            content()
        }
        .frame(maxWidth: .infinity, minHeight: minimumStateHeight)
        .padding(theme.metrics.spacing.content)
        .background(
            RoundedRectangle(
                cornerRadius: theme.metrics.sizing.cornerRadius,
                style: .continuous
            )
            .fill(theme.palette.surface)
        )
    }

    private func actionButton(
        _ title: String,
        isDestructive: Bool,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(theme.typography.action)
                .foregroundStyle(.white)
                .frame(
                    maxWidth: .infinity,
                    minHeight: theme.metrics.sizing.minimumActionHeight
                )
                .background(
                    RoundedRectangle(
                        cornerRadius: theme.metrics.sizing.cornerRadius,
                        style: .continuous
                    )
                    .fill(isDestructive ? Color.red : theme.palette.accent)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(BroadNoPressEffectButtonStyle())
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .day()
                .month(.wide)
                .year()
                .locale(Locale(identifier: "ru_RU"))
        )
    }

    private var minimumStateHeight: CGFloat {
        theme.metrics.sizing.minimumProductHeight * 2
    }
}
