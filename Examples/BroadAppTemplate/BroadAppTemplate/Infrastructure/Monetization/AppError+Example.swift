import BroadCore

extension AppError {
    static func example(
        message: String,
        code: String
    ) -> AppError {
        AppError(
            kind: .unavailable,
            userMessage: message,
            diagnosticCode: code,
            isRetryable: true
        )
    }
}
