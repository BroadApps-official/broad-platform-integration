import BroadUIFlows
import SwiftUI

struct RootView: View {
    @ObservedObject private var viewModel: RootViewModel
    private let scenarioCatalog: [ExampleScenarioCatalogItem]
    private let onSelectScenario: ((ExampleScenarioRoute) -> Void)?

    init(
        viewModel: RootViewModel,
        scenarioCatalog: [ExampleScenarioCatalogItem] = [],
        onSelectScenario: ((ExampleScenarioRoute) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.scenarioCatalog = scenarioCatalog
        self.onSelectScenario = onSelectScenario
    }

    var body: some View {
        ZStack {
            AppTokens.Color.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppTokens.Spacing.section) {
                    header

                    loadableSection
                }
                .padding(.horizontal, AppTokens.Spacing.screenHorizontal)
                .padding(.vertical, AppTokens.Spacing.screenVertical)
            }
        }
        .onAppear(perform: viewModel.startIfNeeded)
    }

    private var loadableSection: some View {
        BroadLoadableView(
            state: viewModel.moduleState,
            content: { modules in
                stateContent(modules: modules)
            },
            idle: {
                stateContent(modules: nil)
            },
            loading: {
                stateContent(modules: nil)
            },
            refreshIndicator: {
                EmptyView()
            },
            empty: {
                stateContent(modules: nil)
            },
            staleBanner: { _ in
                EmptyView()
            },
            failure: { _, previousModules in
                stateContent(modules: previousModules)
            }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppTokens.Spacing.small) {
            Text(viewModel.content.eyebrow)
                .font(AppTokens.Font.eyebrow)
                .foregroundStyle(AppTokens.Color.accent)

            Text(viewModel.content.title)
                .font(AppTokens.Font.heroTitle)
                .foregroundStyle(AppTokens.Color.primaryText)

            Text(viewModel.content.subtitle)
                .font(AppTokens.Font.body)
                .foregroundStyle(AppTokens.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func moduleList(_ modules: [RootViewModel.ModuleItem]) -> some View {
        VStack(spacing: AppTokens.Spacing.cardGap) {
            ForEach(modules) { module in
                ModuleCardView(module: module)
            }
        }
    }

    private func stateContent(
        modules: [RootViewModel.ModuleItem]?
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTokens.Spacing.section) {
            if let modules {
                moduleList(modules)
            }

            BootstrapStatusCardView(
                state: viewModel.bootstrapStatusCardState,
                onRetry: viewModel.retry
            )

            if !scenarioCatalog.isEmpty, let onSelectScenario {
                scenarioCatalogSection(
                    items: scenarioCatalog,
                    onSelect: onSelectScenario
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scenarioCatalogSection(
        items: [ExampleScenarioCatalogItem],
        onSelect: @escaping (ExampleScenarioRoute) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTokens.Spacing.cardGap) {
            VStack(alignment: .leading, spacing: AppTokens.Spacing.tiny) {
                Text("Безопасный каталог сценариев")
                    .font(AppTokens.Font.heroTitle)
                    .foregroundStyle(AppTokens.Color.primaryText)

                Text(
                    "Откройте нужный экран и проверьте поведение без настоящей оплаты и production-запросов."
                )
                .font(AppTokens.Font.body)
                .foregroundStyle(AppTokens.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(items) { item in
                Button {
                    onSelect(item.route)
                } label: {
                    ExampleScenarioCatalogCard(item: item)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("catalog.\(item.route.rawValue)")
            }
        }
    }
}

struct ExampleScenarioCatalogItem: Identifiable, Equatable {
    let route: ExampleScenarioRoute
    let title: String
    let explanation: String
    let systemImage: String
    let tint: Color

    var id: ExampleScenarioRoute {
        route
    }
}

enum ExampleScenarioRoute: String, Identifiable, CaseIterable {
    case appFlow = "app-flow"
    case subscriptionPaywall = "subscription-paywall"
    case tokenPaywall = "token-paywall"
    case specialOffer = "special-offer"
    case ruBilling = "ru-billing"
    case loaderAndErrors = "loader-errors"
    case analytics
    case contactUs = "contact-us"
    case debugStorage = "debug-storage"

    var id: String {
        rawValue
    }
}

private struct ExampleScenarioCatalogCard: View {
    let item: ExampleScenarioCatalogItem

    var body: some View {
        HStack(spacing: AppTokens.Spacing.cardContent) {
            Image(systemName: item.systemImage)
                .font(AppTokens.Font.moduleIcon)
                .foregroundStyle(item.tint)
                .frame(
                    width: AppTokens.Size.moduleIcon,
                    height: AppTokens.Size.moduleIcon
                )
                .background(item.tint.opacity(AppTokens.Opacity.iconBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppTokens.Radius.icon))

            VStack(alignment: .leading, spacing: AppTokens.Spacing.tiny) {
                Text(item.title)
                    .font(AppTokens.Font.cardTitle)
                    .foregroundStyle(AppTokens.Color.primaryText)

                Text(item.explanation)
                    .font(AppTokens.Font.caption)
                    .foregroundStyle(AppTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: AppTokens.Spacing.small)

            Image(systemName: "chevron.right")
                .font(AppTokens.Font.badge)
                .foregroundStyle(item.tint)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTokens.Spacing.cardPadding)
        .background(AppTokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTokens.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: AppTokens.Radius.card)
                .stroke(
                    item.tint.opacity(AppTokens.Opacity.border),
                    lineWidth: AppTokens.Border.thin
                )
        }
        .contentShape(Rectangle())
    }
}
