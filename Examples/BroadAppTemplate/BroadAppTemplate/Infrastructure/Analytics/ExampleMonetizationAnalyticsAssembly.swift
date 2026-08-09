import BroadMonetization

enum ExampleMonetizationAnalyticsAssembly {
    static func make(
        recorder: ExampleRecordingMonetizationAnalytics
    ) -> any MonetizationAnalyticsProtocol {
        let destinations = CompositeMonetizationAnalytics(
            destinations: [recorder]
        )
        let deduplicated = DeduplicatingMonetizationAnalytics(
            destination: destinations
        )
        return NonBlockingMonetizationAnalytics(
            destination: deduplicated
        )
    }
}
