import BroadMonetization

public struct BroadUIFlowsModule: Equatable, Sendable {
    public let identifier: String
    public let monetizationIdentifier: String

    public init(
        identifier: String = "BroadUIFlows",
        monetizationIdentifier: String
    ) {
        self.identifier = identifier
        self.monetizationIdentifier = monetizationIdentifier
    }
}
