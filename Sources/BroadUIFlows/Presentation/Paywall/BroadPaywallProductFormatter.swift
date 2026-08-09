import BroadMonetization
import Foundation

public struct BroadPaywallPeriodCopy: Equatable, Sendable {
    public struct UnitCopy: Equatable, Sendable {
        public let singular: String
        public let plural: String

        public init(
            singular: String,
            plural: String
        ) {
            self.singular = singular
            self.plural = plural
        }
    }

    public let perPrefix: String
    public let everyPrefix: String
    public let day: UnitCopy
    public let week: UnitCopy
    public let month: UnitCopy
    public let year: UnitCopy
    public let unknownTitle: String?

    public init(
        perPrefix: String,
        everyPrefix: String,
        day: UnitCopy,
        week: UnitCopy,
        month: UnitCopy,
        year: UnitCopy,
        unknownTitle: String? = nil
    ) {
        self.perPrefix = perPrefix
        self.everyPrefix = everyPrefix
        self.day = day
        self.week = week
        self.month = month
        self.year = year
        self.unknownTitle = unknownTitle
    }

    public static let english = BroadPaywallPeriodCopy(
        perPrefix: "per",
        everyPrefix: "every",
        day: UnitCopy(singular: "day", plural: "days"),
        week: UnitCopy(singular: "week", plural: "weeks"),
        month: UnitCopy(singular: "month", plural: "months"),
        year: UnitCopy(singular: "year", plural: "years")
    )
}

public struct BroadPaywallProductFormatter: Sendable {
    public let locale: Locale
    public let periodCopy: BroadPaywallPeriodCopy

    public init(
        locale: Locale = .autoupdatingCurrent,
        periodCopy: BroadPaywallPeriodCopy = .english
    ) {
        self.locale = locale
        self.periodCopy = periodCopy
    }

    public func price(for product: MonetizationProduct) -> String? {
        // A localized provider string is presentation metadata, not proof that
        // the underlying amount/currency was decoded safely. Without Money the
        // row must use the app's explicit unavailable copy.
        guard let money = product.price else {
            return nil
        }

        if let displayPrice = product.displayPrice {
            return displayPrice
        }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = money.currencyCode
        return formatter.string(from: money.amount as NSDecimalNumber)
    }

    public func period(for product: MonetizationProduct) -> String? {
        period(product.subscriptionPeriod)
    }

    public func period(_ period: SubscriptionPeriod) -> String? {
        switch period.unit {
        case .day:
            formattedKnownPeriod(count: period.count, copy: periodCopy.day)
        case .week:
            formattedKnownPeriod(count: period.count, copy: periodCopy.week)
        case .month:
            formattedKnownPeriod(count: period.count, copy: periodCopy.month)
        case .year:
            formattedKnownPeriod(count: period.count, copy: periodCopy.year)
        case let .custom(unit):
            formattedCustomPeriod(count: period.count, unit: unit)
        case .unknown:
            periodCopy.unknownTitle
        }
    }

    private func formattedKnownPeriod(
        count: Int?,
        copy: BroadPaywallPeriodCopy.UnitCopy
    ) -> String? {
        guard let count else {
            return nil
        }

        if count == 1 {
            return "\(periodCopy.perPrefix) \(copy.singular)"
        }

        return "\(periodCopy.everyPrefix) \(count) \(copy.plural)"
    }

    private func formattedCustomPeriod(
        count: Int?,
        unit: String
    ) -> String {
        guard let count else {
            return unit
        }

        if count == 1 {
            return "\(periodCopy.perPrefix) \(unit)"
        }

        return "\(periodCopy.everyPrefix) \(count) \(unit)"
    }
}
