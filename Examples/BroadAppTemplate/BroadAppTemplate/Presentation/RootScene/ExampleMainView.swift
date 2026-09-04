import BroadCore
import BroadMonetization
import BroadUIFlows
import SwiftUI

struct ExampleMainView: View {
    let rootViewModel: RootViewModel
    let paywallViewModel: PaywallViewModel
    let specialOfferViewModel: ExampleSpecialOfferFixtureViewModel
    @ObservedObject var tokenPaywallViewModel: BroadTokenPaywallViewModel
    @ObservedObject var tokenBalanceViewModel: ExampleTokenBalanceViewModel
    let analyticsViewModel: ExampleAnalyticsViewModel
    let supportEmailRequest: () -> BroadSupportEmailRequest?

    @State private var selectedScenario: ExampleScenarioRoute?

    #if DEBUG
        @State private var isShowingDebugScenarios = false
        @StateObject private var debugSettingsViewModel: ExampleDebugSettingsViewModel

        init(
            rootViewModel: RootViewModel,
            paywallViewModel: PaywallViewModel,
            specialOfferViewModel: ExampleSpecialOfferFixtureViewModel,
            tokenPaywallViewModel: BroadTokenPaywallViewModel,
            tokenBalanceViewModel: ExampleTokenBalanceViewModel,
            analyticsViewModel: ExampleAnalyticsViewModel,
            supportEmailRequest: @escaping () -> BroadSupportEmailRequest?,
            debugSettingsViewModel: ExampleDebugSettingsViewModel
        ) {
            self.rootViewModel = rootViewModel
            self.paywallViewModel = paywallViewModel
            self.specialOfferViewModel = specialOfferViewModel
            self.tokenPaywallViewModel = tokenPaywallViewModel
            self.tokenBalanceViewModel = tokenBalanceViewModel
            self.analyticsViewModel = analyticsViewModel
            self.supportEmailRequest = supportEmailRequest
            _debugSettingsViewModel = StateObject(
                wrappedValue: debugSettingsViewModel
            )
        }
    #else
        init(
            rootViewModel: RootViewModel,
            paywallViewModel: PaywallViewModel,
            specialOfferViewModel: ExampleSpecialOfferFixtureViewModel,
            tokenPaywallViewModel: BroadTokenPaywallViewModel,
            tokenBalanceViewModel: ExampleTokenBalanceViewModel,
            analyticsViewModel: ExampleAnalyticsViewModel,
            supportEmailRequest: @escaping () -> BroadSupportEmailRequest?
        ) {
            self.rootViewModel = rootViewModel
            self.paywallViewModel = paywallViewModel
            self.specialOfferViewModel = specialOfferViewModel
            self.tokenPaywallViewModel = tokenPaywallViewModel
            self.tokenBalanceViewModel = tokenBalanceViewModel
            self.analyticsViewModel = analyticsViewModel
            self.supportEmailRequest = supportEmailRequest
        }
    #endif

    var body: some View {
        RootView(
            viewModel: rootViewModel,
            scenarioCatalog: scenarioCatalog,
            onSelectScenario: { selectedScenario = $0 }
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                completionBanner
                ExampleTokenBalanceButton(
                    tokenPaywallViewModel: tokenPaywallViewModel,
                    tokenBalanceViewModel: tokenBalanceViewModel,
                    action: { selectedScenario = .tokenPaywall }
                )
            }
        }
        .fullScreenCover(item: $selectedScenario) { route in
            scenarioDestination(route)
        }
        #if DEBUG
        .sheet(isPresented: $isShowingDebugScenarios) {
                ExampleDebugScenariosView(
                    analyticsViewModel: analyticsViewModel,
                    settingsViewModel: debugSettingsViewModel,
                    onOpenScenario: openScenarioFromDebug
                )
            }
        #endif
            .task {
                tokenPaywallViewModel.recoverAccountBalanceIfNeeded()
                tokenPaywallViewModel.recoverPendingPurchaseIfNeeded()
            }
    }

    private var scenarioCatalog: [ExampleScenarioCatalogItem] {
        var items = [
            ExampleScenarioCatalogItem(
                route: .appFlow,
                title: "Основной flow",
                explanation: "Посмотреть порядок launch → onboarding → paywall → main.",
                systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                tint: AppTokens.Color.core
            ),
            ExampleScenarioCatalogItem(
                route: .subscriptionPaywall,
                title: "Subscription paywall",
                explanation: "Безопасно открыть подписочный пейвол с fixture-продуктами.",
                systemImage: "crown.fill",
                tint: AppTokens.Color.monetization
            ),
            ExampleScenarioCatalogItem(
                route: .tokenPaywall,
                title: "Token paywall",
                explanation: "Проверить отдельный каталог пакетов токенов без выдачи premium.",
                systemImage: "circle.grid.2x2.fill",
                tint: AppTokens.Color.warning
            ),
            ExampleScenarioCatalogItem(
                route: .specialOffer,
                title: "Special offer",
                explanation: "Открыть опциональное предложение после закрытия обычного пейвола.",
                systemImage: "tag.fill",
                tint: AppTokens.Color.uiFlows
            ),
            ExampleScenarioCatalogItem(
                route: .ruBilling,
                title: "RU Billing",
                explanation: "Посмотреть выбор Apple, СБП и карты без настоящего платежа.",
                systemImage: "creditcard.fill",
                tint: AppTokens.Color.monetization
            ),
            ExampleScenarioCatalogItem(
                route: .loaderAndErrors,
                title: "Loader и ошибки",
                explanation: "Проверить мгновенную ромашку, ошибку и повтор запроса.",
                systemImage: "arrow.triangle.2.circlepath",
                tint: AppTokens.Color.failure
            ),
            ExampleScenarioCatalogItem(
                route: .analytics,
                title: "Аналитика",
                explanation: "Посмотреть события fixture-paywall текущего запуска.",
                systemImage: "chart.bar.xaxis",
                tint: AppTokens.Color.accent
            ),
            ExampleScenarioCatalogItem(
                route: .contactUs,
                title: "Contact Us",
                explanation: "Проверить письмо поддержки и fallback без настроенной почты.",
                systemImage: "envelope.fill",
                tint: AppTokens.Color.core
            )
        ]

        #if DEBUG
            items.append(
                ExampleScenarioCatalogItem(
                    route: .debugStorage,
                    title: "Debug-хранилища",
                    explanation: "Безопасно проверить Keychain, progress, кеш и аналитику.",
                    systemImage: "externaldrive.fill.badge.gearshape",
                    tint: AppTokens.Color.warning
                )
            )
        #endif

        return items
    }

    #if DEBUG
        private func openScenarioFromDebug(
            _ route: ExampleScenarioRoute
        ) {
            isShowingDebugScenarios = false
            selectedScenario = nil
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 350_000_000)
                selectedScenario = route
            }
        }
    #endif

    private var completionBanner: some View {
        HStack(spacing: AppTokens.Spacing.small) {
            Image(systemName: "checkmark.seal.fill")
                .font(AppTokens.Font.mainIcon)
                .foregroundStyle(AppTokens.Color.success)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppTokens.Spacing.tiny) {
                Text("Сценарий завершён")
                    .font(AppTokens.Font.cardTitle)
                    .foregroundStyle(AppTokens.Color.primaryText)

                Text("Основной экран открыт по выбранной flow-политике.")
                    .font(AppTokens.Font.caption)
                    .foregroundStyle(AppTokens.Color.secondaryText)
            }

            Spacer(minLength: 0)

            #if DEBUG
                Button {
                    isShowingDebugScenarios = true
                } label: {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(AppTokens.Font.moduleIcon)
                        .foregroundStyle(AppTokens.Color.warning)
                        .frame(
                            width: AppTokens.Size.moduleIcon,
                            height: AppTokens.Size.moduleIcon
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Открыть отладочные сценарии")
            #endif
        }
        .padding(.horizontal, AppTokens.Spacing.screenHorizontal)
        .padding(.vertical, AppTokens.Spacing.small)
        .background(AppTokens.Color.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTokens.Color.border)
                .frame(height: AppTokens.Border.thin)
        }
    }
}

private extension ExampleMainView {
    @ViewBuilder
    func scenarioDestination(
        _ route: ExampleScenarioRoute
    ) -> some View {
        switch route {
        case .appFlow:
            ExampleFlowExplanationView()
        case .subscriptionPaywall:
            ExampleCatalogPaywallView(viewModel: paywallViewModel)
        case .tokenPaywall:
            BroadTokenPaywallView(
                viewModel: tokenPaywallViewModel,
                theme: AppTokens.paywallTheme,
                productFormatter: BroadPaywallProductFormatter(
                    locale: Locale(identifier: "ru_RU"),
                    periodCopy: .russian
                ),
                onClose: { selectedScenario = nil }
            )
            .preferredColorScheme(.dark)
        case .specialOffer:
            ExampleSpecialOfferCatalogFlowView(
                subscriptionPaywallViewModel: paywallViewModel,
                specialOfferViewModel: specialOfferViewModel
            )
        case .ruBilling:
            ExampleRUPaymentSheetFixtureView(initialMethod: .sbp)
        case .loaderAndErrors:
            ExampleLoaderAndErrorsView()
        case .analytics:
            ExampleAnalyticsCatalogView(
                viewModel: analyticsViewModel,
                paywallViewModel: paywallViewModel
            )
        case .contactUs:
            ExampleContactUsView(
                request: supportEmailRequest()
            )
        case .debugStorage:
            #if DEBUG
                ExampleDebugScenariosView(
                    analyticsViewModel: analyticsViewModel,
                    settingsViewModel: debugSettingsViewModel,
                    onOpenScenario: openScenarioFromDebug
                )
            #else
                ExampleFlowExplanationView()
            #endif
        }
    }
}
