import BroadCore
import Dispatch
import Foundation

enum ExampleBootstrapScenario: String {
    case ready
    case degraded
    case failedOnce
    case seedCache
    case staleCache

    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> ExampleBootstrapScenario {
        if arguments.contains("-bootstrap-stale-cache") {
            return .staleCache
        }

        if arguments.contains("-bootstrap-seed-cache") {
            return .seedCache
        }

        if arguments.contains("-bootstrap-failed-once") {
            return .failedOnce
        }

        if arguments.contains("-bootstrap-degraded") {
            return .degraded
        }

        return .ready
    }

    func makeSteps(
        requiredServiceFailureMessage: String,
        cacheRepository: any CacheRepositoryProtocol,
        cacheKey: CacheKey<ExampleCachedConfiguration>,
        cacheValue: ExampleCachedConfiguration,
        staleCacheMessage: String,
        missingCacheMessage: String,
        invalidCacheMessage: String
    ) -> [BootstrapStep] {
        let failureGate = ExampleFailureGate()

        return [
            BootstrapStep(
                id: BootstrapStepID(rawValue: "local-configuration"),
                name: "Configuration cache and refresh",
                criticality: .critical,
                timeoutPolicy: .seconds(1),
                retryPolicy: .none
            ) {
                try await ContinuousClock().sleep(for: .milliseconds(120))
                return try await localConfigurationResult(
                    cacheRepository: cacheRepository,
                    cacheKey: cacheKey,
                    cacheValue: cacheValue,
                    staleCacheMessage: staleCacheMessage,
                    missingCacheMessage: missingCacheMessage,
                    invalidCacheMessage: invalidCacheMessage
                )
            },
            BootstrapStep(
                id: BootstrapStepID(rawValue: "required-services"),
                name: "Required services",
                criticality: .critical,
                timeoutPolicy: .seconds(1),
                retryPolicy: .none
            ) {
                try await ContinuousClock().sleep(for: .milliseconds(180))

                if self == .failedOnce, await failureGate.consumeFailure() {
                    throw AppError(
                        kind: .unavailable,
                        userMessage: requiredServiceFailureMessage,
                        diagnosticCode: "example.required-service.failed-once",
                        isRetryable: true
                    )
                }

                return .completed
            },
            makeBackgroundStep()
        ]
    }

    private func localConfigurationResult(
        cacheRepository: any CacheRepositoryProtocol,
        cacheKey: CacheKey<ExampleCachedConfiguration>,
        cacheValue: ExampleCachedConfiguration,
        staleCacheMessage: String,
        missingCacheMessage: String,
        invalidCacheMessage: String
    ) async throws -> BootstrapStepCompletion {
        switch self {
        case .seedCache:
            try await cacheRepository.write(cacheValue, for: cacheKey)
            return .completed
        case .staleCache:
            return try await staleCacheResult(
                cacheRepository: cacheRepository,
                cacheKey: cacheKey,
                expectedValue: cacheValue,
                staleCacheMessage: staleCacheMessage,
                missingCacheMessage: missingCacheMessage,
                invalidCacheMessage: invalidCacheMessage
            )
        case .ready, .degraded, .failedOnce:
            return .completed
        }
    }

    private func staleCacheResult(
        cacheRepository: any CacheRepositoryProtocol,
        cacheKey: CacheKey<ExampleCachedConfiguration>,
        expectedValue: ExampleCachedConfiguration,
        staleCacheMessage: String,
        missingCacheMessage: String,
        invalidCacheMessage: String
    ) async throws -> BootstrapStepCompletion {
        switch try await cacheRepository.read(cacheKey) {
        case let .fresh(envelope):
            try validate(envelope.value, expectedValue: expectedValue, message: invalidCacheMessage)
            return .completed
        case let .stale(envelope):
            try validate(envelope.value, expectedValue: expectedValue, message: invalidCacheMessage)
            return await refreshStaleConfiguration(staleCacheMessage: staleCacheMessage)
        case let .missing(reason):
            throw AppError(
                kind: reason == .notFound ? .offline : .decoding,
                userMessage: reason == .notFound ? missingCacheMessage : invalidCacheMessage,
                diagnosticCode: diagnosticCode(for: reason),
                isRetryable: false
            )
        }
    }

    private func refreshStaleConfiguration(
        staleCacheMessage: String
    ) async -> BootstrapStepCompletion {
        do {
            _ = try await ExampleTimedOutConfigurationLoader().load()
            return .completed
        } catch {
            return .degraded(
                AppError(
                    kind: .timeout,
                    userMessage: staleCacheMessage,
                    diagnosticCode: "example.cache.stale-timeout-fallback",
                    isRetryable: false
                )
            )
        }
    }

    private func validate(
        _ value: ExampleCachedConfiguration,
        expectedValue: ExampleCachedConfiguration,
        message: String
    ) throws {
        guard value == expectedValue else {
            throw AppError(
                kind: .decoding,
                userMessage: message,
                diagnosticCode: "example.cache.unexpected-value",
                isRetryable: false
            )
        }
    }

    private func diagnosticCode(for reason: CacheMissReason) -> String {
        switch reason {
        case .notFound:
            "example.cache.not-found"
        case .corrupted:
            "example.cache.corrupted"
        case .schemaMismatch:
            "example.cache.schema-mismatch"
        case .versionMismatch:
            "example.cache.version-mismatch"
        }
    }

    private func makeBackgroundStep() -> BootstrapStep {
        BootstrapStep(
            id: BootstrapStepID(rawValue: "optional-telemetry"),
            name: "Optional telemetry",
            criticality: .background,
            timeoutPolicy: .seconds(self == .degraded ? 0.25 : 1),
            retryPolicy: .none
        ) {
            if self == .degraded {
                await ExampleBootstrapDelay.waitIgnoringCancellation(milliseconds: 1200)
            } else {
                try await ContinuousClock().sleep(for: .milliseconds(220))
            }

            return .completed
        }
    }
}

struct ExampleCachedConfiguration: Codable, Equatable, Sendable {
    let source: String
}

private struct ExampleTimedOutConfigurationLoader: Sendable {
    func load() async throws -> ExampleCachedConfiguration {
        try await ContinuousClock().sleep(for: .milliseconds(80))
        throw ExampleConfigurationTimeoutError()
    }
}

private struct ExampleConfigurationTimeoutError: Error, Sendable {}

private actor ExampleFailureGate {
    private var mustFail = true

    func consumeFailure() -> Bool {
        guard mustFail else {
            return false
        }

        mustFail = false
        return true
    }
}

private enum ExampleBootstrapDelay {
    static func waitIgnoringCancellation(milliseconds: Int) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).asyncAfter(
                deadline: .now() + .milliseconds(milliseconds)
            ) {
                continuation.resume()
            }
        }
    }
}
