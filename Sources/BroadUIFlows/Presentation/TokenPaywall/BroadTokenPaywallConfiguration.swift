import BroadMonetization
import Foundation

public struct BroadTokenPaywallCopy: Equatable, Sendable {
    public struct Header: Equatable, Sendable {
        public let title: String
        public let subtitle: String
        public let balanceTitle: String

        public init(
            title: String,
            subtitle: String,
            balanceTitle: String
        ) {
            self.title = title
            self.subtitle = subtitle
            self.balanceTitle = balanceTitle
        }
    }

    public struct Products: Equatable, Sendable {
        public let fallbackTitle: String
        public let unavailablePriceTitle: String
        public let selectedAccessibilityValue: String

        public init(
            fallbackTitle: String,
            unavailablePriceTitle: String,
            selectedAccessibilityValue: String
        ) {
            self.fallbackTitle = fallbackTitle
            self.unavailablePriceTitle = unavailablePriceTitle
            self.selectedAccessibilityValue = selectedAccessibilityValue
        }
    }

    public struct Actions: Equatable, Sendable {
        public let purchaseTitle: String
        public let purchasingTitle: String
        public let retryTitle: String
        public let retryingTitle: String
        public let recoverBalanceTitle: String
        public let recoveringBalanceTitle: String
        public let closeAccessibilityLabel: String

        public init(
            purchaseTitle: String,
            purchasingTitle: String,
            retryTitle: String,
            retryingTitle: String,
            recoverBalanceTitle: String,
            recoveringBalanceTitle: String,
            closeAccessibilityLabel: String
        ) {
            self.purchaseTitle = purchaseTitle
            self.purchasingTitle = purchasingTitle
            self.retryTitle = retryTitle
            self.retryingTitle = retryingTitle
            self.recoverBalanceTitle = recoverBalanceTitle
            self.recoveringBalanceTitle = recoveringBalanceTitle
            self.closeAccessibilityLabel = closeAccessibilityLabel
        }
    }

    public struct States: Equatable, Sendable {
        public let loadingTitle: String
        public let emptyTitle: String
        public let emptyMessage: String
        public let errorTitle: String
        public let pendingMessage: String
        public let cancelledMessage: String
        public let creditedMessage: String
        public let recoveredMessage: String

        public init(
            loadingTitle: String,
            emptyTitle: String,
            emptyMessage: String,
            errorTitle: String,
            pendingMessage: String,
            cancelledMessage: String,
            creditedMessage: String,
            recoveredMessage: String
        ) {
            self.loadingTitle = loadingTitle
            self.emptyTitle = emptyTitle
            self.emptyMessage = emptyMessage
            self.errorTitle = errorTitle
            self.pendingMessage = pendingMessage
            self.cancelledMessage = cancelledMessage
            self.creditedMessage = creditedMessage
            self.recoveredMessage = recoveredMessage
        }
    }

    public struct Analytics: Equatable, Sendable {
        public let title: String
        public let emptyMessage: String

        public init(title: String, emptyMessage: String) {
            self.title = title
            self.emptyMessage = emptyMessage
        }
    }

    public let header: Header
    public let products: Products
    public let actions: Actions
    public let states: States
    public let analytics: Analytics

    public init(
        header: Header,
        products: Products,
        actions: Actions,
        states: States,
        analytics: Analytics
    ) {
        self.header = header
        self.products = products
        self.actions = actions
        self.states = states
        self.analytics = analytics
    }
}

public extension BroadTokenPaywallCopy {
    static let russian = BroadTokenPaywallCopy(
        header: Header(
            title: "Пополнить токены",
            subtitle: "Consumable-пакеты не открывают premium и подтверждаются backend.",
            balanceTitle: "Подтверждённый баланс"
        ),
        products: Products(
            fallbackTitle: "Пакет токенов",
            unavailablePriceTitle: "Цена недоступна",
            selectedAccessibilityValue: "Выбрано"
        ),
        actions: Actions(
            purchaseTitle: "Купить fixture-пакет",
            purchasingTitle: "Проверяем покупку…",
            retryTitle: "Повторить подтверждение",
            retryingTitle: "Сверяем с backend…",
            recoverBalanceTitle: "Восстановить баланс с backend",
            recoveringBalanceTitle: "Восстанавливаем баланс…",
            closeAccessibilityLabel: "Закрыть token paywall"
        ),
        states: States(
            loadingTitle: "Загружаем token placement",
            emptyTitle: "Пакеты токенов не найдены",
            emptyMessage: "Закройте экран или повторите загрузку позже.",
            errorTitle: "Token paywall недоступен",
            pendingMessage: "Покупка сохранена и ждёт backend-подтверждения.",
            cancelledMessage: "Покупка отменена. Баланс не изменился.",
            creditedMessage: "Backend подтвердил новый баланс.",
            recoveredMessage: "Баланс восстановлен из backend account ledger."
        ),
        analytics: Analytics(
            title: "Token-аналитика этого запуска",
            emptyMessage: "События появятся после загрузки и выбора пакета."
        )
    )
}

public struct BroadTokenPaywallConfiguration: Equatable, Sendable {
    public let copy: BroadTokenPaywallCopy
    public let defaultSelectionIndex: Int

    public init(
        copy: BroadTokenPaywallCopy,
        defaultSelectionIndex: Int = 0
    ) {
        precondition(
            defaultSelectionIndex >= 0,
            "Token paywall selection index must be non-negative"
        )
        self.copy = copy
        self.defaultSelectionIndex = defaultSelectionIndex
    }

    public var request: PaywallLoadRequest {
        PaywallLoadRequest(placementID: .tokens)
    }
}
