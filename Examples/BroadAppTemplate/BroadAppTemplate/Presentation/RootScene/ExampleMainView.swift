import BroadMonetization
import SwiftUI

struct ExampleMainView: View {
    let rootViewModel: RootViewModel
    let analyticsViewModel: ExampleAnalyticsViewModel

    #if DEBUG
        @State private var isShowingDebugScenarios = false
    #endif

    var body: some View {
        RootView(viewModel: rootViewModel)
            .safeAreaInset(edge: .top, spacing: 0) {
                completionBanner
            }
        #if DEBUG
            .sheet(isPresented: $isShowingDebugScenarios) {
                ExampleDebugScenariosView(
                    analyticsViewModel: analyticsViewModel
                )
            }
        #endif
    }

    private var completionBanner: some View {
        HStack(spacing: AppTokens.Spacing.small) {
            Image(systemName: "checkmark.seal.fill")
                .font(AppTokens.Font.mainIcon)
                .foregroundStyle(AppTokens.Color.success)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppTokens.Spacing.tiny) {
                Text("Flow complete")
                    .font(AppTokens.Font.cardTitle)
                    .foregroundStyle(AppTokens.Color.primaryText)

                Text("Onboarding and verified monetization are resolved.")
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
                .accessibilityLabel("Open debug scenarios")
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

#if DEBUG
    private struct ExampleDebugScenariosView: View {
        @ObservedObject var analyticsViewModel: ExampleAnalyticsViewModel

        private let scenarios = [
            "-live-adapty            real catalog; purchase/restore disabled",
            "-analytics-fixture       paywall + typed recording sink",
            "-paywall-one-product     1 product, automatic selection",
            "-paywall-two-products    2 products, original order",
            "-paywall-many-products   12 products, original order",
            "-paywall-payment-methods Apple/SBP/Card sheet fixture",
            "-paywall-empty           safe empty paywall",
            "-paywall-failure         retryable load error",
            "-purchase-cancelled      cancellation without error",
            "-purchase-pending        pending without premium",
            "-purchase-failure        retryable purchase error",
            "-restore-nothing         explicit inactive restore"
        ]

        var body: some View {
            NavigationStack {
                List {
                    Section("Launch arguments") {
                        ForEach(scenarios, id: \.self) { scenario in
                            Text(scenario)
                                .font(AppTokens.Font.caption)
                        }
                    }

                    Section("Recorded analytics") {
                        if analyticsViewModel.events.isEmpty {
                            Text("No monetization events recorded yet.")
                                .font(AppTokens.Font.caption)
                                .foregroundStyle(AppTokens.Color.secondaryText)
                        } else {
                            ForEach(analyticsViewModel.events) { record in
                                VStack(alignment: .leading, spacing: AppTokens.Spacing.tiny) {
                                    Text("\(record.id). \(record.event.exampleName)")
                                        .font(AppTokens.Font.cardTitle)

                                    Text(record.event.exampleSummary)
                                        .font(AppTokens.Font.caption)
                                        .foregroundStyle(AppTokens.Color.secondaryText)
                                        .textSelection(.enabled)
                                }
                            }
                        }

                        Button("Refresh recorded events") {
                            Task {
                                await analyticsViewModel.refresh()
                            }
                        }

                        Button("Clear recorded events", role: .destructive) {
                            Task {
                                await analyticsViewModel.reset()
                            }
                        }
                    }
                }
                .navigationTitle("Debug scenarios")
                .task {
                    await analyticsViewModel.refresh()
                }
                .refreshable {
                    await analyticsViewModel.refresh()
                }
            }
        }
    }
#endif
