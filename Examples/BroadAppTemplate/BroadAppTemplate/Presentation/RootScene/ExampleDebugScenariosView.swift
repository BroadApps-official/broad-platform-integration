import BroadCore
import BroadMonetization
import BroadUIFlows
import SwiftUI

#if DEBUG
    struct ExampleDebugScenariosView: View {
        @ObservedObject var analyticsViewModel: ExampleAnalyticsViewModel
        @ObservedObject var settingsViewModel: ExampleDebugSettingsViewModel
        let onOpenScenario: (ExampleScenarioRoute) -> Void
        @State private var isConfirmingKeychainCleanup = false
        @State private var isConfirmingFlowReset = false
        @Environment(\.dismiss) private var dismiss

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
                                isEnabled: settingsViewModel.activeStorageAction == nil,
                                isInFlight: settingsViewModel.isBackendActionInFlight,
                                action: settingsViewModel.runBackendActionFixture
                            ),
                            tint: AppTokens.Color.accent
                        )

                        if let feedback = settingsViewModel.backendFeedback {
                            Label(feedback.title, systemImage: "checkmark.circle.fill")
                                .font(AppTokens.Font.cardTitle)
                                .foregroundStyle(AppTokens.Color.success)
                            Text(feedback.message)
                                .font(AppTokens.Font.caption)
                                .foregroundStyle(AppTokens.Color.secondaryText)
                        }
                    }

                    storageSections

                    ExampleRUBillingDebugOverrideSection(
                        settingsViewModel: settingsViewModel,
                        onOpenPaywall: {
                            onOpenScenario(.subscriptionPaywall)
                        }
                    )

                    ExampleLaunchScenariosSections(
                        onOpenScenario: onOpenScenario
                    )

                    Section("События для просмотра") {
                        if analyticsViewModel.events.isEmpty {
                            Text(
                                analyticsViewModel.lastUpdatedAt == nil
                                    ? "Событий монетизации пока нет. Откройте безопасный paywall из каталога."
                                    : "Обновление завершено: событий пока нет. Откройте безопасный paywall из каталога."
                            )
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

                        Button {
                            analyticsViewModel.requestRefresh()
                        } label: {
                            HStack {
                                Text(
                                    analyticsViewModel.isRefreshing
                                        ? "Обновляем события…"
                                        : "Обновить события"
                                )
                                Spacer()
                                if analyticsViewModel.isRefreshing {
                                    ProgressView()
                                } else if let lastUpdatedAt = analyticsViewModel.lastUpdatedAt {
                                    Text(lastUpdatedAt, style: .time)
                                        .font(AppTokens.Font.caption)
                                        .foregroundStyle(AppTokens.Color.secondaryText)
                                }
                            }
                        }
                        .disabled(
                            analyticsViewModel.isRefreshing
                                || analyticsViewModel.isClearing
                        )
                    }
                }
                .navigationTitle("Debug-настройки")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") {
                            dismiss()
                        }
                        .accessibilityIdentifier("debug.close")
                    }
                }
                .task {
                    await analyticsViewModel.refresh()
                }
                .refreshable {
                    await analyticsViewModel.refresh()
                }
                .onChange(of: settingsViewModel.feedback[.analytics]) { _, feedback in
                    guard feedback?.isSuccess == true else {
                        return
                    }
                    Task {
                        await analyticsViewModel.refresh()
                    }
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
                        "Удалятся только app-owned credentials. Flow, кеш, аналитика и платёжные записи останутся."
                    )
                }
                .confirmationDialog(
                    "Сбросить onboarding и начальный paywall?",
                    isPresented: $isConfirmingFlowReset,
                    titleVisibility: .visible
                ) {
                    Button("Сбросить", role: .destructive) {
                        settingsViewModel.resetFlowProgress()
                    }
                    Button("Отмена", role: .cancel) {}
                } message: {
                    Text(
                        "Keychain, кеш, аналитика, покупки и entitlement не удалятся. Для нового flow нужен перезапуск."
                    )
                }
            }
            .preferredColorScheme(.dark)
        }

        @ViewBuilder
        private var storageSections: some View {
            debugStorageSection(
                configuration: DebugStorageSectionConfiguration(
                    title: "1. Keychain",
                    explanation: "Удаляет только credentials приложения из разрешённых сервисов.",
                    keeps: "Не удаляет: onboarding, paywall, кеш, аналитику, покупки и pending.",
                    restart: "Перезапуск нужен, чтобы заново создать сессию.",
                    buttonTitle: "Очистить Keychain",
                    inFlightTitle: "Очищаем Keychain…",
                    action: .keychain,
                    tint: AppTokens.Color.failure
                )
            ) {
                isConfirmingKeychainCleanup = true
            }

            debugStorageSection(
                configuration: DebugStorageSectionConfiguration(
                    title: "2. Прогресс onboarding/paywall",
                    explanation: "Удаляет только две checkpoint-отметки текущего flow.",
                    keeps: "Не удаляет: Keychain, кеш, аналитику, покупки и entitlement.",
                    restart: "Перезапуск обязателен: текущий экран сам не меняется.",
                    buttonTitle: "Сбросить прогресс flow",
                    inFlightTitle: "Сбрасываем progress…",
                    action: .flowProgress,
                    tint: AppTokens.Color.warning
                )
            ) {
                isConfirmingFlowReset = true
            }

            debugStorageSection(
                configuration: DebugStorageSectionConfiguration(
                    title: "3. Кеш контента",
                    explanation: "Удаляет только сохранённую fixture-конфигурацию bootstrap.",
                    keeps: "Не удаляет: Keychain, flow, аналитику, paywall-кеш и доступ.",
                    restart: "Перезапуск не нужен; эффект виден при следующем чтении кеша.",
                    buttonTitle: "Очистить кеш контента",
                    inFlightTitle: "Очищаем кеш…",
                    action: .contentCache,
                    tint: AppTokens.Color.core
                ),
                perform: settingsViewModel.clearContentCache
            )

            debugStorageSection(
                configuration: DebugStorageSectionConfiguration(
                    title: "4. In-memory аналитика",
                    explanation: "Удаляет только события, записанные fixture-рекордером в этом процессе.",
                    keeps: "Не удаляет: production-аналитику, Keychain, flow, кеш и покупки.",
                    restart: "Перезапуск не нужен; список ниже обновится на следующем шаге.",
                    buttonTitle: "Очистить записанную аналитику",
                    inFlightTitle: "Очищаем события…",
                    action: .analytics,
                    tint: AppTokens.Color.uiFlows
                )
            ) {
                settingsViewModel.clearAnalytics()
            }
        }

        private func debugStorageSection(
            configuration: DebugStorageSectionConfiguration,
            perform: @escaping () -> Void
        ) -> some View {
            Section(configuration.title) {
                Text(configuration.explanation)
                    .font(AppTokens.Font.body)
                Text(configuration.keeps)
                    .font(AppTokens.Font.caption)
                    .foregroundStyle(AppTokens.Color.secondaryText)
                Text(configuration.restart)
                    .font(AppTokens.Font.caption)
                    .foregroundStyle(AppTokens.Color.warning)

                BroadActionButton(
                    configuration: BroadActionConfiguration(
                        title: configuration.buttonTitle,
                        inFlightTitle: configuration.inFlightTitle,
                        isEnabled: settingsViewModel.activeStorageAction == nil,
                        isInFlight: settingsViewModel.activeStorageAction == configuration.action,
                        action: perform
                    ),
                    tint: configuration.tint
                )
                .accessibilityIdentifier(
                    "debug-storage.\(configuration.action.accessibilityName)"
                )

                if let feedback = settingsViewModel.feedback[configuration.action] {
                    ExampleDebugStorageFeedbackView(feedback: feedback)
                }
            }
        }
    }

    private struct DebugStorageSectionConfiguration {
        let title: String
        let explanation: String
        let keeps: String
        let restart: String
        let buttonTitle: String
        let inFlightTitle: String
        let action: ExampleDebugStorageAction
        let tint: Color
    }

    struct ExampleDebugSettingsNotice: Equatable {
        let title: String
        let message: String
    }

    private struct ExampleDebugStorageFeedbackView: View {
        let feedback: ExampleDebugStorageFeedback

        var body: some View {
            VStack(alignment: .leading, spacing: AppTokens.Spacing.tiny) {
                Label(
                    feedback.title,
                    systemImage: feedback.isSuccess
                        ? "checkmark.circle.fill"
                        : "exclamationmark.triangle.fill"
                )
                .font(AppTokens.Font.cardTitle)
                .foregroundStyle(
                    feedback.isSuccess
                        ? AppTokens.Color.success
                        : AppTokens.Color.failure
                )

                Text(feedback.message)
                    .font(AppTokens.Font.caption)
                Text("Удалено записей: \(feedback.removedCount)")
                    .font(AppTokens.Font.caption)
                    .bold()
                Text(feedback.requiresRestart ? "Нужен перезапуск" : "Перезапуск не нужен")
                    .font(AppTokens.Font.caption)
                    .foregroundStyle(AppTokens.Color.secondaryText)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private struct ExampleRUBillingDebugOverrideSection: View {
        @ObservedObject var settingsViewModel: ExampleDebugSettingsViewModel
        let onOpenPaywall: () -> Void

        var body: some View {
            Section("5. RU Billing — только Debug") {
                Text(
                    "В Release ru_pay всегда читается из текущего payload Adapty. "
                        + "Здесь можно временно переопределить только этот флаг для UI-проверки."
                )
                .font(AppTokens.Font.body)

                Picker(
                    "Источник ru_pay",
                    selection: Binding(
                        get: { settingsViewModel.ruBillingOverrideMode },
                        set: { mode in
                            settingsViewModel.updateRUBillingOverride(mode)
                        }
                    )
                ) {
                    ForEach(RUBillingDebugOverrideMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.inline)
                .accessibilityIdentifier("debug.ru-billing.override")

                Text(settingsViewModel.ruBillingOverrideMode.explanation)
                    .font(AppTokens.Font.caption)
                    .foregroundStyle(AppTokens.Color.secondaryText)

                Text(
                    "Force Enabled не обходит host configuration, российский Storefront "
                        + "или регион iPhone, "
                        + "RU-каталог, backend authorization и entitlement-проверку."
                )
                .font(AppTokens.Font.caption)
                .foregroundStyle(AppTokens.Color.warning)

                Button("Открыть subscription paywall", action: onOpenPaywall)
                    .accessibilityIdentifier("debug.ru-billing.open-paywall")
            }
        }
    }

    private extension ExampleDebugStorageAction {
        var accessibilityName: String {
            switch self {
            case .keychain: "keychain"
            case .flowProgress: "flow-progress"
            case .contentCache: "content-cache"
            case .analytics: "analytics"
            }
        }
    }

    private extension RUBillingDebugOverrideMode {
        var title: String {
            switch self {
            case .followAdapty: "Как в Adapty"
            case .forceEnabled: "Включить"
            case .forceDisabled: "Выключить"
            }
        }

        var explanation: String {
            switch self {
            case .followAdapty:
                "Используется настоящий ru_pay из Remote Config текущего paywall."
            case .forceEnabled:
                "Debug временно считает ru_pay включённым. Remote Config не изменяется."
            case .forceDisabled:
                "Debug временно скрывает RU-методы, даже если Adapty вернул true."
            }
        }
    }
#endif
