import BroadMonetization

enum BroadRUBillingPeriodFormatter {
    static func russian(_ period: SubscriptionPeriod) -> String {
        guard let count = period.count else {
            return ""
        }
        switch period.unit {
        case .day:
            return count == 1 ? "в день" : "каждые \(count) дн."
        case .week:
            return count == 1 ? "в неделю" : "каждые \(count) нед."
        case .month:
            return count == 1 ? "в месяц" : "каждые \(count) мес."
        case .year:
            return count == 1 ? "в год" : "каждые \(count) г."
        case let .custom(value):
            return count == 1 ? value : "\(count) \(value)"
        case .unknown:
            return ""
        }
    }
}
