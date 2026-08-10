import BroadMonetization

struct ExampleRestoreRepository: RestoreRepositoryProtocol {
    let accessState: ExamplePremiumAccessState
    let arguments: [String]

    func restorePurchases() async -> RestoreAttemptOutcome {
        if arguments.contains("-restore-failure") {
            return .failed(
                .example(
                    message: "Restore is temporarily unavailable.",
                    code: "example.restore.failed"
                )
            )
        }
        if !arguments.contains("-restore-nothing") {
            await accessState.activate()
        }
        return .completed
    }
}
