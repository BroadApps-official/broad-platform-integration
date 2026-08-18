#if DEBUG
    import BroadCore
    import Foundation
    import Security

    /// One exact, app-owned generic-password service that can be cleared from
    /// development settings. A missing access group means the app's default
    /// Keychain access group.
    struct DebugKeychainScope: Equatable, Hashable, Sendable {
        let service: String
        let accessGroup: String?

        init(
            service: String,
            accessGroup: String? = nil
        ) {
            let normalizedService = service.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let normalizedAccessGroup = accessGroup?.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            precondition(
                !normalizedService.isEmpty,
                "Debug Keychain service must not be empty"
            )
            precondition(
                normalizedAccessGroup?.isEmpty != true,
                "Debug Keychain access group must not be empty"
            )

            self.service = normalizedService
            self.accessGroup = normalizedAccessGroup
        }
    }

    enum DebugKeychainCleanupOutcome: Equatable, Sendable {
        case completed(
            clearedServiceCount: Int,
            alreadyEmptyServiceCount: Int
        )
        case failed(AppError)
    }

    /// Debug-only cleaner for exact Keychain services owned by the host app.
    ///
    /// It never runs at launch and never deletes an unscoped Keychain class.
    /// Release builds do not contain this type.
    actor DebugKeychainCleaner {
        private let scopes: [DebugKeychainScope]
        private let failureError: AppError

        init(
            scopes: [DebugKeychainScope],
            failureError: AppError
        ) {
            precondition(
                !scopes.isEmpty,
                "Debug Keychain cleaner requires at least one app-owned service"
            )
            precondition(
                Set(scopes).count == scopes.count,
                "Debug Keychain cleaner scopes must be unique"
            )

            self.scopes = scopes
            self.failureError = failureError
        }

        func clear() -> DebugKeychainCleanupOutcome {
            var clearedServiceCount = 0
            var alreadyEmptyServiceCount = 0

            for scope in scopes {
                let status = SecItemDelete(query(for: scope) as CFDictionary)
                switch status {
                case errSecSuccess:
                    clearedServiceCount += 1
                case errSecItemNotFound:
                    alreadyEmptyServiceCount += 1
                default:
                    return .failed(failureError)
                }
            }

            return .completed(
                clearedServiceCount: clearedServiceCount,
                alreadyEmptyServiceCount: alreadyEmptyServiceCount
            )
        }
    }

    private extension DebugKeychainCleaner {
        func query(
            for scope: DebugKeychainScope
        ) -> [String: Any] {
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: scope.service
            ]

            if let accessGroup = scope.accessGroup {
                query[kSecAttrAccessGroup as String] = accessGroup
            }

            return query
        }
    }
#endif
