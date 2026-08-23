public protocol AppFlowProgressRepositoryProtocol: Sendable {
    func loadCheckpoint() async -> AppFlowCheckpoint

    @discardableResult
    func advance(to checkpoint: AppFlowCheckpoint) async -> AppFlowCheckpoint

    /// Removes only the persisted onboarding and initial-paywall checkpoints.
    ///
    /// This operation never touches Keychain, entitlement, purchase or content
    /// cache data. It is intended for an explicit host-controlled debug action.
    @discardableResult
    func reset() async throws -> Int
}
