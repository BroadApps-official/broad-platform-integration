public protocol AppFlowProgressRepositoryProtocol: Sendable {
    func loadCheckpoint() async -> AppFlowCheckpoint

    @discardableResult
    func advance(to checkpoint: AppFlowCheckpoint) async -> AppFlowCheckpoint
}
