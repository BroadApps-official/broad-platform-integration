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
                Text("Сценарий завершён")
                    .font(AppTokens.Font.cardTitle)
                    .foregroundStyle(AppTokens.Color.primaryText)

                Text("Онбординг завершён, доступ после покупки проверен.")
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

#if DEBUG
    private struct ExampleDebugScenariosView: View {
        @ObservedObject var analyticsViewModel: ExampleAnalyticsViewModel

        private let scenarios = [
            "-live-adapty            реальный каталог; покупка и восстановление отключены",
            "-analytics-fixture       пейвол и запись типизированной аналитики",
            "-paywall-one-product     1 продукт, выбирается автоматически",
            "-paywall-two-products    2 продукта в исходном порядке",
            "-paywall-many-products   12 продуктов в исходном порядке",
            "-paywall-payment-methods тестовый экран Apple/СБП/карта",
            "-ru-subscription-management активная RU-подписка",
            "-ru-subscription-cancelled доступ до даты, автопродление выключено",
            "-ru-payment-sheet       согласия СБП и чек по email",
            "-ru-payment-sheet-apple Apple без RU-полей",
            "-paywall-empty           безопасное состояние без продуктов",
            "-paywall-failure         ошибка загрузки с повтором",
            "-purchase-cancelled      отмена покупки без ошибки",
            "-purchase-pending        ожидание без выдачи премиум-доступа",
            "-purchase-failure        ошибка покупки с повтором",
            "-restore-nothing         восстановление без активной покупки"
        ]

        var body: some View {
            NavigationStack {
                List {
                    Section("Аргументы запуска") {
                        ForEach(scenarios, id: \.self) { scenario in
                            Text(scenario)
                                .font(AppTokens.Font.caption)
                        }
                    }

                    Section("Записанная аналитика") {
                        if analyticsViewModel.events.isEmpty {
                            Text("Событий монетизации пока нет.")
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

                        Button("Обновить события") {
                            Task {
                                await analyticsViewModel.refresh()
                            }
                        }

                        Button("Очистить события", role: .destructive) {
                            Task {
                                await analyticsViewModel.reset()
                            }
                        }
                    }
                }
                .navigationTitle("Отладочные сценарии")
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
