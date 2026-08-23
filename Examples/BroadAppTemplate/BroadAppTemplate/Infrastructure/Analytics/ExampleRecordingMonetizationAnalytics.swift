import BroadCore
import BroadMonetization
import Foundation

struct ExampleRecordedMonetizationEvent: Identifiable, Equatable, Sendable {
    let id: UInt64
    let event: MonetizationAnalyticsEvent
}

/// In-memory, typed fixture destination. It stores only the platform's safe
/// analytics event model and never accepts arbitrary dictionaries or raw SDK data.
actor ExampleRecordingMonetizationAnalytics: MonetizationAnalyticsProtocol {
    private let retainedEventLimit: Int
    private let logger: any BroadLoggerProtocol
    private var nextSequence: UInt64 = 0
    private var events: [ExampleRecordedMonetizationEvent] = []
    private var updateContinuations: [
        UUID: AsyncStream<[ExampleRecordedMonetizationEvent]>.Continuation
    ] = [:]

    init(
        retainedEventLimit: Int = 256,
        logger: any BroadLoggerProtocol = NoOpBroadLogger()
    ) {
        precondition(
            retainedEventLimit > 0,
            "Example analytics retention must be positive"
        )
        self.retainedEventLimit = retainedEventLimit
        self.logger = logger
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
        logger.log(.analyticsEventsRecorded(count: events.count))
        publishSnapshot()
    }

    func snapshot() -> [ExampleRecordedMonetizationEvent] {
        events
    }

    func updates() -> AsyncStream<[ExampleRecordedMonetizationEvent]> {
        let observerID = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            updateContinuations[observerID] = continuation
            continuation.yield(events)
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeContinuation(observerID)
                }
            }
        }
    }

    @discardableResult
    func reset() -> Int {
        let removedEventCount = events.count
        events.removeAll(keepingCapacity: true)
        logger.log(.analyticsEventsRecorded(count: 0))
        publishSnapshot()
        return removedEventCount
    }

    private func publishSnapshot() {
        for continuation in updateContinuations.values {
            continuation.yield(events)
        }
    }

    private func removeContinuation(_ observerID: UUID) {
        updateContinuations.removeValue(forKey: observerID)
    }
}
