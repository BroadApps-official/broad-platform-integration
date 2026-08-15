import BroadMonetization
import Foundation

public struct BroadPaywallPurchaseStateCopy: Equatable, Sendable {
    public let pendingMessage: String
    public let completedMessage: String
    public let completedButUnverifiedMessage: String

    public init(
        pendingMessage: String,
        completedMessage: String = "The purchase completed.",
        completedButUnverifiedMessage: String
    ) {
        self.pendingMessage = pendingMessage
        self.completedMessage = completedMessage
        self.completedButUnverifiedMessage = completedButUnverifiedMessage
    }
}

public enum BroadPaywallDefaultSelection: Equatable, Sendable {
    case presentationID(ProductPresentationID)
    case productID(ProductID)
    case index(Int)

    func resolve(in products: [MonetizationProduct]) -> ProductPresentationID? {
        switch self {
        case let .presentationID(presentationID):
            return products.first { product in
                product.presentationID == presentationID
                    && product.isEligibleForGenericPurchase
            }?.presentationID
        case let .productID(productID):
            return products.first { product in
                product.productID == productID
                    && product.isEligibleForGenericPurchase
            }?.presentationID
        case let .index(index):
            guard products.indices.contains(index),
                  products[index].isEligibleForGenericPurchase
            else {
                return nil
            }
            return products[index].presentationID
        }
    }
}

public struct BroadPaywallAccessConfiguration: Equatable, Sendable {
    public static let defaultHardPaywallCloseDelay: TimeInterval = 5
    public static let maximumHardPaywallCloseDelay: TimeInterval = 30

    public let defaultPolicy: PaywallAccessPolicy

    /// `nil` uses a finite safe default. Values above the public maximum are
    /// capped so malformed app configuration cannot lock the screen.
    public let hardPaywallCloseDelay: TimeInterval?

    public init(
        defaultPolicy: PaywallAccessPolicy = .soft,
        hardPaywallCloseDelay: TimeInterval? = nil
    ) {
        self.defaultPolicy = defaultPolicy
        self.hardPaywallCloseDelay = Self.normalized(delay: hardPaywallCloseDelay)
    }

    static func normalized(delay: TimeInterval?) -> TimeInterval {
        guard let delay, delay.isFinite, delay >= 0 else {
            return defaultHardPaywallCloseDelay
        }

        return min(delay, maximumHardPaywallCloseDelay)
    }
}

public struct BroadPaywallLegalLink: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let accessibilityLabel: String?
    public let url: URL

    public init(
        id: String,
        title: String,
        accessibilityLabel: String? = nil,
        url: URL
    ) {
        precondition(!id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Legal link ID must not be empty")
        precondition(!title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Legal link title must not be empty")
        precondition(url.scheme?.lowercased() == "https", "Paywall legal links must use HTTPS")

        self.id = id
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.url = url
    }
}

public struct BroadPaywallSpecialOfferCopy: Equatable, Sendable {
    public let crossedValueAccessibilityLabel: String
    public let multiplierAccessibilityLabel: String
    public let countdownAccessibilityLabel: String
    public let expiredMessage: String

    public init(
        crossedValueAccessibilityLabel: String,
        multiplierAccessibilityLabel: String,
        countdownAccessibilityLabel: String,
        expiredMessage: String = "This offer has ended. Close the screen or choose another offer."
    ) {
        self.crossedValueAccessibilityLabel = crossedValueAccessibilityLabel
        self.multiplierAccessibilityLabel = multiplierAccessibilityLabel
        self.countdownAccessibilityLabel = countdownAccessibilityLabel
        self.expiredMessage = expiredMessage
    }

    public static let english = BroadPaywallSpecialOfferCopy(
        crossedValueAccessibilityLabel: "Previous price",
        multiplierAccessibilityLabel: "Value multiplier",
        countdownAccessibilityLabel: "Offer time remaining",
        expiredMessage: "This offer has ended. Close the screen or choose another offer."
    )
}

public struct BroadPaywallCopy: Equatable, Sendable {
    public struct Header: Equatable, Sendable {
        public let title: String
        public let subtitle: String?

        public init(
            title: String,
            subtitle: String? = nil
        ) {
            self.title = title
            self.subtitle = subtitle
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
        public let restoreTitle: String
        public let restoringTitle: String
        public let retryTitle: String
        public let closeAccessibilityLabel: String
        public let cancelTitle: String

        public init(
            purchaseTitle: String,
            restoreTitle: String,
            restoringTitle: String,
            retryTitle: String,
            closeAccessibilityLabel: String,
            cancelTitle: String
        ) {
            self.purchaseTitle = purchaseTitle
            self.restoreTitle = restoreTitle
            self.restoringTitle = restoringTitle
            self.retryTitle = retryTitle
            self.closeAccessibilityLabel = closeAccessibilityLabel
            self.cancelTitle = cancelTitle
        }
    }

    public struct States: Equatable, Sendable {
        public let loadingTitle: String
        public let errorTitle: String
        public let emptyTitle: String
        public let emptyMessage: String
        public let checkoutUnavailableMessage: String
        public let nothingToRestoreMessage: String
        public let purchase: BroadPaywallPurchaseStateCopy

        public init(
            loadingTitle: String,
            errorTitle: String,
            emptyTitle: String,
            emptyMessage: String,
            checkoutUnavailableMessage: String,
            nothingToRestoreMessage: String,
            purchase: BroadPaywallPurchaseStateCopy
        ) {
            self.loadingTitle = loadingTitle
            self.errorTitle = errorTitle
            self.emptyTitle = emptyTitle
            self.emptyMessage = emptyMessage
            self.checkoutUnavailableMessage = checkoutUnavailableMessage
            self.nothingToRestoreMessage = nothingToRestoreMessage
            self.purchase = purchase
        }
    }

    public struct Checkout: Equatable, Sendable {
        public let title: String
        public let appleTitle: String
        public let sbpTitle: String
        public let cardTitle: String

        public init(
            title: String,
            appleTitle: String,
            sbpTitle: String,
            cardTitle: String
        ) {
            self.title = title
            self.appleTitle = appleTitle
            self.sbpTitle = sbpTitle
            self.cardTitle = cardTitle
        }

        public func title(for method: CheckoutMethod) -> String {
            switch method {
            case .apple:
                appleTitle
            case .sbp:
                sbpTitle
            case .card:
                cardTitle
            }
        }
    }

    public let header: Header
    public let products: Products
    public let actions: Actions
    public let states: States
    public let checkout: Checkout

    public init(
        header: Header,
        products: Products,
        actions: Actions,
        states: States,
        checkout: Checkout
    ) {
        self.header = header
        self.products = products
        self.actions = actions
        self.states = states
        self.checkout = checkout
    }

    public static let standard = BroadPaywallCopy(
        header: Header(
            title: "Choose your plan",
            subtitle: "Select the option that works for you."
        ),
        products: Products(
            fallbackTitle: "Premium access",
            unavailablePriceTitle: "Price unavailable",
            selectedAccessibilityValue: "Selected"
        ),
        actions: Actions(
            purchaseTitle: "Continue",
            restoreTitle: "Restore",
            restoringTitle: "Restoring",
            retryTitle: "Try again",
            closeAccessibilityLabel: "Close paywall",
            cancelTitle: "Cancel"
        ),
        states: States(
            loadingTitle: "Loading available plans",
            errorTitle: "Plans are unavailable",
            emptyTitle: "No plans are available",
            emptyMessage: "Close this screen or try again later.",
            checkoutUnavailableMessage: "This payment method is currently unavailable.",
            nothingToRestoreMessage: "No purchases were found to restore.",
            purchase: BroadPaywallPurchaseStateCopy(
                pendingMessage: "The purchase is waiting for confirmation.",
                completedMessage: "The purchase completed.",
                completedButUnverifiedMessage: "The purchase completed, but access could not be confirmed yet."
            )
        ),
        checkout: Checkout(
            title: "Choose a payment method",
            appleTitle: "App Store",
            sbpTitle: "Fast Payments System",
            cardTitle: "Bank card"
        )
    )
}

public struct BroadPaywallConfiguration: Equatable, Sendable {
    public let request: PaywallLoadRequest
    public let defaultSelection: BroadPaywallDefaultSelection?
    public let access: BroadPaywallAccessConfiguration
    public let copy: BroadPaywallCopy
    public let legalLinks: [BroadPaywallLegalLink]
    public let ruBilling: BroadRUBillingPresentationConfiguration?
    public let specialOfferCopy: BroadPaywallSpecialOfferCopy
    public let specialOfferAuthorization: SpecialOfferPresentationAuthorization?

    public var specialOfferExpiresAt: Date? {
        specialOfferAuthorization?.expiresAt
    }

    public init(
        placementID: PlacementID,
        defaultSelection: BroadPaywallDefaultSelection? = nil,
        access: BroadPaywallAccessConfiguration = BroadPaywallAccessConfiguration(),
        copy: BroadPaywallCopy = .standard,
        legalLinks: [BroadPaywallLegalLink] = [],
        ruBilling: BroadRUBillingPresentationConfiguration? = nil,
        specialOfferCopy: BroadPaywallSpecialOfferCopy = .english,
        specialOfferAuthorization: SpecialOfferPresentationAuthorization? = nil
    ) {
        precondition(
            Set(legalLinks.map(\.id)).count == legalLinks.count,
            "Paywall legal links require unique IDs"
        )
        request = PaywallLoadRequest(placementID: placementID)
        self.defaultSelection = defaultSelection
        self.access = access
        self.copy = copy
        self.legalLinks = legalLinks
        self.ruBilling = ruBilling
        self.specialOfferCopy = specialOfferCopy
        self.specialOfferAuthorization = specialOfferAuthorization
    }
}
