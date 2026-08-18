import BroadCore
import BroadMonetization
import BroadUIFlows
import SwiftUI

struct ExampleMainView: View {
    let rootViewModel: RootViewModel
    let analyticsViewModel: ExampleAnalyticsViewModel

    #if DEBUG
        @State private var isShowingDebugScenarios = false
        @StateObject private var debugSettingsViewModel: ExampleDebugSettingsViewModel

        init(
            rootViewModel: RootViewModel,
            analyticsViewModel: ExampleAnalyticsViewModel,
            debugSettingsViewModel: ExampleDebugSettingsViewModel
        ) {
            self.rootViewModel = rootViewModel
            self.analyticsViewModel = analyticsViewModel
            _debugSettingsViewModel = StateObject(
                wrappedValue: debugSettingsViewModel
            )
        }
    #else
        init(
            rootViewModel: RootViewModel,
            analyticsViewModel: ExampleAnalyticsViewModel
        ) {
            self.rootViewModel = rootViewModel
            self.analyticsViewModel = analyticsViewModel
        }
    #endif

    var body: some View {
        RootView(viewModel: rootViewModel)
            .safeAreaInset(edge: .top, spacing: 0) {
                completionBanner
            }
        #if DEBUG
            .sheet(isPresented: $isShowingDebugScenarios) {
                ExampleDebugScenariosView(
                    analyticsViewModel: analyticsViewModel,
                    settingsViewModel: debugSettingsViewModel
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
        @ObservedObject var settingsViewModel: ExampleDebugSettingsViewModel
        @State private var isConfirmingKeychainCleanup = false

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
                    Section("Мгновенный отклик backend-кнопки") {
                        Text(
                            "Ромашка появляется сразу после нажатия, кнопка блокируется, а затем открывается результат или ошибка."
                        )
                        .font(AppTokens.Font.caption)
                        .foregroundStyle(AppTokens.Color.secondaryText)

                        BroadActionButton(
                            configuration: BroadActionConfiguration(
                                title: "Проверить loader",
                                inFlightTitle: "Ждём ответ backend…",
                                isEnabled: !settingsViewModel.isClearingKeychain,
                                isInFlight: settingsViewModel.isBackendActionInFlight,
                                action: settingsViewModel.runBackendActionFixture
                            ),
                            tint: AppTokens.Color.accent
                        )
                    }

                    Section("Хранилище разработки") {
                        Text(
                            "Очищаются только Keychain-сервисы, перечисленные в AppConfiguration. Release-сборка этой функции не содержит."
                        )
                        .font(AppTokens.Font.caption)
                        .foregroundStyle(AppTokens.Color.secondaryText)

                        BroadActionButton(
                            configuration: BroadActionConfiguration(
                                title: "Очистить Keychain",
                                inFlightTitle: "Очищаем Keychain…",
                                isEnabled: !settingsViewModel.isBackendActionInFlight,
                                isInFlight: settingsViewModel.isClearingKeychain
                            ) {
                                isConfirmingKeychainCleanup = true
                            },
                            tint: AppTokens.Color.failure
                        )
                    }

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
                .navigationTitle("Debug-настройки")
                .task {
                    await analyticsViewModel.refresh()
                }
                .refreshable {
                    await analyticsViewModel.refresh()
                }
                .confirmationDialog(
                    "Очистить Keychain приложения?",
                    isPresented: $isConfirmingKeychainCleanup,
                    titleVisibility: .visible
                ) {
                    Button("Очистить", role: .destructive) {
                        settingsViewModel.clearKeychain()
                    }
                    Button("Отмена", role: .cancel) {}
                } message: {
                    Text(
                        "Потребуется заново войти в тестовый аккаунт. Платёжные pending-записи эта кнопка не удаляет."
                    )
                }
                .alert(item: $settingsViewModel.notice) { notice in
                    Alert(
                        title: Text(notice.title),
                        message: Text(notice.message),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
    }

    struct ExampleDebugSettingsNotice: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String
    }

    @MainActor
    final class ExampleDebugSettingsViewModel: ObservableObject {
        @Published private(set) var isBackendActionInFlight = false
        @Published private(set) var isClearingKeychain = false
        @Published var notice: ExampleDebugSettingsNotice?

        private let keychainCleaner: DebugKeychainCleaner
        private var backendTask: Task<Void, Never>?
        private var keychainTask: Task<Void, Never>?

        init(keychainCleaner: DebugKeychainCleaner) {
            self.keychainCleaner = keychainCleaner
        }

        deinit {
            backendTask?.cancel()
            keychainTask?.cancel()
        }

        func runBackendActionFixture() {
            guard backendTask == nil else {
                return
            }

            isBackendActionInFlight = true
            backendTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard let self, !Task.isCancelled else {
                    return
                }

                backendTask = nil
                isBackendActionInFlight = false
                notice = ExampleDebugSettingsNotice(
                    title: "Ответ получен",
                    message: "Во время ожидания кнопка сразу показывала ромашку и не принимала повторный тап."
                )
            }
        }

        func clearKeychain() {
            guard keychainTask == nil else {
                return
            }

            isClearingKeychain = true
            let cleaner = keychainCleaner
            keychainTask = Task { @MainActor [weak self, cleaner] in
                let outcome = await cleaner.clear()
                guard let self, !Task.isCancelled else {
                    return
                }

                keychainTask = nil
                isClearingKeychain = false
                apply(outcome)
            }
        }

        private func apply(
            _ outcome: DebugKeychainCleanupOutcome
        ) {
            switch outcome {
            case let .completed(clearedServiceCount, alreadyEmptyServiceCount):
                notice = ExampleDebugSettingsNotice(
                    title: "Keychain очищен",
                    message: clearedServiceCount > 0
                        ? "Очищено сервисов: \(clearedServiceCount). Перезапустите сценарий и войдите заново."
                        : "Данные уже отсутствовали. Проверено сервисов: \(alreadyEmptyServiceCount)."
                )
            case let .failed(error):
                notice = ExampleDebugSettingsNotice(
                    title: "Не удалось очистить Keychain",
                    message: error.userMessage
                )
            }
        }
    }
#endif
