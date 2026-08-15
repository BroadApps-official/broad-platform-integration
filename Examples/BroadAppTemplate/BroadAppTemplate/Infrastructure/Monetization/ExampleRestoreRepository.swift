import BroadMonetization

struct ExampleRestoreRepository: RestoreRepositoryProtocol {
    let accessState: ExamplePremiumAccessState
    let arguments: [String]

    func restorePurchases() async -> RestoreAttemptOutcome {
        if arguments.contains("-restore-failure") {
            return .failed(
                .example(
                    message: "Восстановление временно недоступно.",
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
