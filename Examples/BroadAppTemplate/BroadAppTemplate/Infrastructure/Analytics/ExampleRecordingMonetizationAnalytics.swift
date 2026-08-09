import BroadMonetization

struct ExampleRecordedMonetizationEvent: Identifiable, Equatable, Sendable {
    let id: UInt64
    let event: MonetizationAnalyticsEvent
}

/// In-memory, typed fixture destination. It stores only the platform's safe
/// analytics event model and never accepts arbitrary dictionaries or raw SDK data.
actor ExampleRecordingMonetizationAnalytics: MonetizationAnalyticsProtocol {
    private let retainedEventLimit: Int
    private var nextSequence: UInt64 = 0
    private var events: [ExampleRecordedMonetizationEvent] = []

    init(retainedEventLimit: Int = 256) {
        precondition(
            retainedEventLimit > 0,
            "Example analytics retention must be positive"
        )
        self.retainedEventLimit = retainedEventLimit
    }

    func track(
        _ event: MonetizationAnalyticsEvent
    ) {
        nextSequence &+= 1
        if events.count == retainedEventLimit {
            events.removeFirst()
        }
        events.append(
            ExampleRecordedMonetizationEvent(
                id: nextSequence,
                event: event
            )
        )
    }

    func snapshot() -> [ExampleRecordedMonetizationEvent] {
        events
    }

    func reset() {
        events.removeAll(keepingCapacity: true)
    }
}
