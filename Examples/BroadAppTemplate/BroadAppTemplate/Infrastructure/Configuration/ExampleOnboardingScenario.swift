import BroadUIFlows
import Foundation

enum ExampleOnboardingScenario: String, CaseIterable {
    case onePage = "one-page"
    case twoPages = "two-pages"
    case exampleThreePages = "three-pages"
    case fourPages = "four-pages"
    case long
    case customUI = "custom-ui"
    case disabled
    case invalid

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> ExampleOnboardingScenario {
        allCases.first { arguments.contains($0.launchArgument) }
            ?? .exampleThreePages
    }

    var launchArgument: String {
        "-onboarding-\(rawValue)"
    }

    var isEnabled: Bool {
        self != .disabled
    }

    var usesCustomRenderer: Bool {
        self == .customUI
    }

    /// `pages` is the only source of the onboarding length. The platform does
    /// not receive or store a second slide-count value.
    var pages: [OnboardingPageConfiguration] {
        switch self {
        case .onePage:
            Array(Self.onboardingPages.prefix(1))
        case .twoPages:
            Array(Self.onboardingPages.prefix(2))
        case .exampleThreePages, .disabled:
            Array(Self.onboardingPages.prefix(3))
        case .fourPages, .customUI:
            Self.onboardingPages
        case .long:
            Self.onboardingPages + Self.additionalLongFlowPages
        case .invalid:
            []
        }
    }
}

private extension ExampleOnboardingScenario {
    /// Demonstration content only. Add, remove or reorder onboarding pages in
    /// this array; do not add a separate slide-count constant.
    static let onboardingPages = [
        OnboardingPageConfiguration(
            id: "platform-foundation",
            title: "Надёжная основа приложения",
            subtitle: "Запуск, работа без сети и общие состояния готовы до открытия основного экрана.",
            media: OnboardingMediaDescriptor(identifier: "foundation")
        ),
        OnboardingPageConfiguration(
            id: "adaptive-monetization",
            title: "Показываем все тарифы",
            subtitle: "Пейвол принимает продукты провайдера без фильтрации и ограничений по количеству.",
            media: OnboardingMediaDescriptor(identifier: "monetization")
        ),
        OnboardingPageConfiguration(
            id: "verified-access",
            title: "Доступ только после проверки",
            subtitle: "Покупка и восстановление завершаются только после повторной проверки доступа.",
            media: OnboardingMediaDescriptor(identifier: "verified-access")
        ),
        OnboardingPageConfiguration(
            id: "app-owned-design",
            title: "Дизайн принадлежит приложению",
            subtitle: "Можно использовать готовый экран платформы или подключить только общую логику к своему SwiftUI-интерфейсу.",
            media: OnboardingMediaDescriptor(identifier: "app-owned-design")
        )
    ]

    static let additionalLongFlowPages = [
        OnboardingPageConfiguration(
            id: "offline-ready",
            title: "Работаем при нестабильной сети",
            subtitle: "Последнее безопасное состояние остаётся доступным, а повтор запускается явно.",
            media: OnboardingMediaDescriptor(identifier: "offline-ready")
        ),
        OnboardingPageConfiguration(
            id: "experiments-ready",
            title: "Поддерживаем эксперименты",
            subtitle: "Placement и variation сохраняются без второго распределителя.",
            media: OnboardingMediaDescriptor(identifier: "experiments-ready")
        ),
        OnboardingPageConfiguration(
            id: "billing-ready",
            title: "Подключаем подходящую оплату",
            subtitle: "Apple и RU Billing остаются за единым проверяемым доступом.",
            media: OnboardingMediaDescriptor(identifier: "billing-ready")
        ),
        OnboardingPageConfiguration(
            id: "ready-to-build",
            title: "Можно собирать приложение",
            subtitle: "Количество страниц определяется этим массивом и не ограничивается примером.",
            media: OnboardingMediaDescriptor(identifier: "ready-to-build")
        )
    ]
}
