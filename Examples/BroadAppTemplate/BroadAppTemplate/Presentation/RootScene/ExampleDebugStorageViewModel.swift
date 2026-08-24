import BroadCore
import BroadMonetization
import BroadUIFlows
import Foundation

#if DEBUG
    enum ExampleDebugStorageAction: Hashable {
        case keychain
        case flowProgress
        case contentCache
        case analytics
    }

    struct ExampleDebugStorageFeedback: Equatable {
        let title: String
        let message: String
        let removedCount: Int
        let requiresRestart: Bool
        let isSuccess: Bool
    }

    actor ExampleDebugContentCacheCleaner {
        private let repository: any CacheRepositoryProtocol
        private let key: CacheKey<ExampleCachedConfiguration>

        init(
            repository: any CacheRepositoryProtocol,
            key: CacheKey<ExampleCachedConfiguration>
        ) {
            self.repository = repository
            self.key = key
        }

        func clear() async throws -> Int {
            let result = try await repository.read(key)
            let removedCount = switch result {
            case .fresh, .stale:
                1
            case .missing(.notFound):
                0
            case .missing:
                1
            }

            try await repository.remove(key)
            return removedCount
        }
    }

    @MainActor
    final class ExampleDebugSettingsViewModel: ObservableObject {
        @Published private(set) var isBackendActionInFlight = false
        @Published private(set) var activeStorageAction: ExampleDebugStorageAction?
        @Published private(set) var feedback: [
            ExampleDebugStorageAction: ExampleDebugStorageFeedback
        ] = [:]
        @Published private(set) var backendFeedback: ExampleDebugSettingsNotice?
        @Published private(set) var ruBillingOverrideMode: RUBillingDebugOverrideMode

        private let keychainCleaner: DebugKeychainCleaner
        private let progressRepository: any AppFlowProgressRepositoryProtocol
        private let contentCacheCleaner: ExampleDebugContentCacheCleaner
        private let analyticsRecorder: ExampleRecordingMonetizationAnalytics
        private let ruBillingOverrideStore: RUBillingDebugOverrideStore
        private var backendTask: Task<Void, Never>?
        private var storageTask: Task<Void, Never>?

        init(
            keychainCleaner: DebugKeychainCleaner,
            progressRepository: any AppFlowProgressRepositoryProtocol,
            contentCacheCleaner: ExampleDebugContentCacheCleaner,
            analyticsRecorder: ExampleRecordingMonetizationAnalytics,
            ruBillingOverrideStore: RUBillingDebugOverrideStore
        ) {
            self.keychainCleaner = keychainCleaner
            self.progressRepository = progressRepository
            self.contentCacheCleaner = contentCacheCleaner
            self.analyticsRecorder = analyticsRecorder
            self.ruBillingOverrideStore = ruBillingOverrideStore
            ruBillingOverrideMode = ruBillingOverrideStore.currentMode
        }

        deinit {
            backendTask?.cancel()
            storageTask?.cancel()
        }

        func runBackendActionFixture() {
            guard backendTask == nil else {
                return
            }

            isBackendActionInFlight = true
            backendFeedback = nil
            backendTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard let self, !Task.isCancelled else {
                    return
                }

                backendTask = nil
                isBackendActionInFlight = false
                backendFeedback = ExampleDebugSettingsNotice(
                    title: "Ответ получен",
                    message: "Ромашка появилась сразу, а повторный тап был заблокирован."
                )
            }
        }

        func clearKeychain() {
            perform(.keychain) { [keychainCleaner] in
                switch await keychainCleaner.clear() {
                case let .completed(cleared, alreadyEmpty):
                    return ExampleDebugStorageFeedback(
                        title: "Keychain проверен",
                        message: cleared > 0
                            ? "Удалены только app-owned credentials. Пустых сервисов: \(alreadyEmpty)."
                            : "App-owned credentials уже отсутствовали.",
                        removedCount: cleared,
                        requiresRestart: true,
                        isSuccess: true
                    )
                case let .failed(error):
                    return Self.failureFeedback(error.userMessage)
                }
            }
        }

        func resetFlowProgress() {
            perform(.flowProgress) { [progressRepository] in
                do {
                    let count = try await progressRepository.reset()
                    return ExampleDebugStorageFeedback(
                        title: "Прогресс flow сброшен",
                        message: "Удалены только отметки onboarding и начального paywall.",
                        removedCount: count,
                        requiresRestart: true,
                        isSuccess: true
                    )
                } catch {
                    return Self.failureFeedback("Не удалось сбросить прогресс flow.")
                }
            }
        }

        func clearContentCache() {
            perform(.contentCache) { [contentCacheCleaner] in
                do {
                    let count = try await contentCacheCleaner.clear()
                    return ExampleDebugStorageFeedback(
                        title: "Кеш контента очищен",
                        message: "Удалена только fixture-конфигурация bootstrap.",
                        removedCount: count,
                        requiresRestart: false,
                        isSuccess: true
                    )
                } catch {
                    return Self.failureFeedback("Не удалось очистить кеш контента.")
                }
            }
        }

        func clearAnalytics() {
            perform(.analytics) { [analyticsRecorder] in
                let count = await analyticsRecorder.reset()
                return ExampleDebugStorageFeedback(
                    title: "Аналитика очищена",
                    message: "Удалены только fixture-события текущего процесса.",
                    removedCount: count,
                    requiresRestart: false,
                    isSuccess: true
                )
            }
        }

        func updateRUBillingOverride(
            _ mode: RUBillingDebugOverrideMode
        ) {
            ruBillingOverrideStore.update(mode)
            ruBillingOverrideMode = mode
        }

        private func perform(
            _ action: ExampleDebugStorageAction,
            operation: @escaping @Sendable () async -> ExampleDebugStorageFeedback
        ) {
            guard storageTask == nil else {
                return
            }

            activeStorageAction = action
            feedback[action] = nil
            storageTask = Task { @MainActor [weak self] in
                let result = await operation()
                guard let self, !Task.isCancelled else {
                    return
                }

                feedback[action] = result
                activeStorageAction = nil
                storageTask = nil
            }
        }

        private nonisolated static func failureFeedback(
            _ message: String
        ) -> ExampleDebugStorageFeedback {
            ExampleDebugStorageFeedback(
                title: "Действие не выполнено",
                message: message,
                removedCount: 0,
                requiresRestart: false,
                isSuccess: false
            )
        }
    }
#endif
