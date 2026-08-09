public struct BroadStateContent: Equatable, Sendable {
    public let title: String
    public let message: String?
    public let systemImageName: String?

    public init(
        title: String,
        message: String? = nil,
        systemImageName: String? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImageName = systemImageName
    }
}
