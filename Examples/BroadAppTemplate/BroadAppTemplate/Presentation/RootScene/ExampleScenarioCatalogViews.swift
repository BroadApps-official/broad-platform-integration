import BroadMonetization
import BroadUIFlows
import SwiftUI

struct ExampleCatalogNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct ExampleCatalogScreen<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTokens.Color.background.ignoresSafeArea()

                content()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .accessibilityIdentifier("catalog.close")
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct ExampleFlowExplanationView: View {
    var body: some View {
        ExampleCatalogScreen(title: "Основной flow") {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTokens.Spacing.section) {
                    catalogHeader(
                        icon: "point.topleft.down.to.point.bottomright.curvepath",
                        title: "Как пользователь попадает в приложение",
                        message: "Этот экран объясняет безопасный порядок переходов. "
                            + "Premium открывается только после свежей проверки доступа."
                    )

                    ForEach(Array(Self.steps.enumerated()), id: \.offset) { index, step in
                        ExampleFlowStepCard(index: index + 1, step: step)
                    }
                }
                .padding(AppTokens.Spacing.screenHorizontal)
            }
        }
    }

    private static let steps = [
        ExampleFlowStep(
            title: "Запуск",
            message: "Обязательные SDK ограничены timeout, необязательные продолжаются в фоне."
        ),
        ExampleFlowStep(
            title: "Onboarding",
            message: "Количество страниц приходит из конфигурации; ATT — только после первого видимого слайда."
        ),
        ExampleFlowStep(
            title: "Subscription paywall",
            message: "Показывает все продукты провайдера и не запускает RU Billing без разрешающего флага."
        ),
        ExampleFlowStep(
            title: "Проверка доступа",
            message: "Покупка или restore завершают flow только после authoritative entitlement refresh."
        ),
        ExampleFlowStep(
            title: "Main",
            message: "Основной экран открывается без ложного premium-доступа."
        )
    ]
}

struct ExampleFlowStep {
    let title: String
    let message: String
}

struct ExampleFlowStepCard: View {
    let index: Int
    let step: ExampleFlowStep

    var body: some View {
        HStack(alignment: .top, spacing: AppTokens.Spacing.cardContent) {
            Text("\(index)")
                .font(AppTokens.Font.cardTitle)
                .foregroundStyle(.white)
                .frame(
                    width: AppTokens.Size.moduleIcon,
                    height: AppTokens.Size.moduleIcon
                )
                .background(AppTokens.Color.core)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: AppTokens.Spacing.tiny) {
                Text(step.title)
                    .font(AppTokens.Font.cardTitle)
                    .foregroundStyle(AppTokens.Color.primaryText)
                Text(step.message)
                    .font(AppTokens.Font.caption)
                    .foregroundStyle(AppTokens.Color.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(AppTokens.Spacing.cardPadding)
        .background(AppTokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTokens.Radius.card))
    }
}

struct ExampleCatalogPaywallView: View {
    @ObservedObject var viewModel: PaywallViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BroadPaywallView(
            viewModel: viewModel,
            theme: AppTokens.paywallTheme,
            productFormatter: BroadPaywallProductFormatter(
                locale: Locale(identifier: "ru_RU"),
                periodCopy: .russian
            ),
            onClose: { dismiss() },
            onCompleted: { _ in dismiss() }
        )
        .preferredColorScheme(.dark)
    }
}

struct ExampleLoaderAndErrorsView: View {
    @State private var isInFlight = false
    @State private var status = "Выберите сценарий ниже."

    var body: some View {
        ExampleCatalogScreen(title: "Loader и ошибки") {
            VStack(spacing: AppTokens.Spacing.section) {
                catalogHeader(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Отклик начинается сразу",
                    message: "Кнопка показывает ромашку до первого await и блокирует повторный тап."
                )

                if isInFlight {
                    ProgressView("Ждём fixture-backend…")
                        .tint(AppTokens.Color.accent)
                        .foregroundStyle(AppTokens.Color.primaryText)
                } else {
                    Text(status)
                        .font(AppTokens.Font.body)
                        .foregroundStyle(AppTokens.Color.secondaryText)
                        .multilineTextAlignment(.center)
                }

                BroadActionButton(
                    configuration: BroadActionConfiguration(
                        title: "Успешный ответ",
                        inFlightTitle: "Загружаем…",
                        isEnabled: !isInFlight,
                        isInFlight: isInFlight,
                        action: { run(result: "Fixture-backend ответил успешно.") }
                    ),
                    tint: AppTokens.Color.success
                )

                BroadActionButton(
                    configuration: BroadActionConfiguration(
                        title: "Ошибка и повтор",
                        inFlightTitle: "Загружаем…",
                        isEnabled: !isInFlight,
                        isInFlight: isInFlight,
                        action: { run(result: "Сеть недоступна. Повторите запрос безопасной кнопкой.") }
                    ),
                    tint: AppTokens.Color.failure
                )

                Spacer()
            }
            .padding(AppTokens.Spacing.screenHorizontal)
        }
    }

    private func run(result: String) {
        guard !isInFlight else { return }
        isInFlight = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            status = result
            isInFlight = false
        }
    }
}

struct ExampleAnalyticsCatalogView: View {
    @ObservedObject var viewModel: ExampleAnalyticsViewModel
    @ObservedObject var paywallViewModel: PaywallViewModel
    @State private var isShowingSafePaywall = false

    var body: some View {
        ExampleCatalogScreen(title: "Аналитика") {
            List {
                Section {
                    Text(
                        "История хранится только в памяти процесса и обнулится после полного перезапуска приложения."
                    )

                    HStack {
                        Label(
                            "Записей: \(viewModel.events.count)",
                            systemImage: "chart.bar.fill"
                        )
                        Spacer()
                        if let lastUpdatedAt = viewModel.lastUpdatedAt {
                            Text(lastUpdatedAt, style: .time)
                                .foregroundStyle(AppTokens.Color.secondaryText)
                        } else {
                            Text("Ещё не обновлялось")
                                .foregroundStyle(AppTokens.Color.secondaryText)
                        }
                    }

                    if let count = viewModel.lastClearedEventCount {
                        Label(
                            "Удалено событий: \(count)",
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(AppTokens.Color.success)
                    }
                }

                Section("События: \(viewModel.events.count)") {
                    if viewModel.events.isEmpty {
                        Text(
                            "Событий пока нет: покупка для проверки не нужна. Откройте safe paywall, выберите продукт и закройте экран."
                        )
                    } else {
                        ForEach(viewModel.events) { record in
                            VStack(alignment: .leading, spacing: AppTokens.Spacing.tiny) {
                                Text(record.event.exampleName)
                                    .font(AppTokens.Font.cardTitle)
                                Text(record.event.exampleSummary)
                                    .font(AppTokens.Font.caption)
                                    .foregroundStyle(AppTokens.Color.secondaryText)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        isShowingSafePaywall = true
                    } label: {
                        Label(
                            "Открыть безопасный paywall и создать события",
                            systemImage: "rectangle.and.hand.point.up.left.fill"
                        )
                    }

                    Button {
                        viewModel.requestRefresh()
                    } label: {
                        HStack {
                            Text(
                                viewModel.isRefreshing
                                    ? "Обновляем события…"
                                    : "Обновить события"
                            )
                            Spacer()
                            if viewModel.isRefreshing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isRefreshing || viewModel.isClearing)

                    Button(role: .destructive) {
                        viewModel.requestReset()
                    } label: {
                        HStack {
                            Text(
                                viewModel.isClearing
                                    ? "Очищаем события…"
                                    : "Очистить события"
                            )
                            Spacer()
                            if viewModel.isClearing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(
                        viewModel.events.isEmpty
                            || viewModel.isRefreshing
                            || viewModel.isClearing
                    )
                }
            }
            .scrollContentBackground(.hidden)
            .task {
                viewModel.startObserving()
                await viewModel.refresh()
            }
            .fullScreenCover(isPresented: $isShowingSafePaywall) {
                ExampleCatalogPaywallView(viewModel: paywallViewModel)
            }
        }
    }
}

@MainActor
func catalogHeader(
    icon: String,
    title: String,
    message: String
) -> some View {
    VStack(alignment: .leading, spacing: AppTokens.Spacing.small) {
        Image(systemName: icon)
            .font(AppTokens.Font.mainIcon)
            .foregroundStyle(AppTokens.Color.accent)

        Text(title)
            .font(AppTokens.Font.heroTitle)
            .foregroundStyle(AppTokens.Color.primaryText)
            .fixedSize(horizontal: false, vertical: true)

        Text(message)
            .font(AppTokens.Font.body)
            .foregroundStyle(AppTokens.Color.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}
