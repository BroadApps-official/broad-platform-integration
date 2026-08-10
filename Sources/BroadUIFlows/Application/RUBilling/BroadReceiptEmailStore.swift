import BroadCore
import Foundation

public protocol BroadReceiptEmailStoreProtocol: Sendable {
    func loadEmail(forKey key: String) async -> String?
    func saveEmail(_ email: String, forKey key: String) async
}

/// Small adapter over the app's existing key-value store. Receipt email is a
/// form preference, never part of entitlement or pending-payment cache.
public struct BroadKeyValueReceiptEmailStore:
    BroadReceiptEmailStoreProtocol {
    private let store: any KeyValueStoreProtocol
    private let maximumUTF8Length: Int

    public init(
        store: any KeyValueStoreProtocol,
        maximumUTF8Length: Int = 320
    ) {
        precondition(
            maximumUTF8Length > 0,
            "Receipt email length limit must be positive"
        )
        self.store = store
        self.maximumUTF8Length = maximumUTF8Length
    }

    public func loadEmail(forKey key: String) async -> String? {
        guard let entry = try? await store.read(key),
              case let .data(data) = entry,
              data.count <= maximumUTF8Length,
              let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    public func saveEmail(_ email: String, forKey key: String) async {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              let data = normalized.data(using: .utf8),
              data.count <= maximumUTF8Length
        else {
            return
        }
        try? await store.write(data, forKey: key)
    }
}
