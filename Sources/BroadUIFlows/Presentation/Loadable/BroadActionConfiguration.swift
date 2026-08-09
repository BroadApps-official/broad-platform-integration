import SwiftUI

@MainActor
public struct BroadActionConfiguration {
    public let title: String
    public let inFlightTitle: String?
    public let accessibilityLabel: String?
    public let isEnabled: Bool
    public let isInFlight: Bool
    public let action: @MainActor () -> Void

    public init(
        title: String,
        inFlightTitle: String? = nil,
        accessibilityLabel: String? = nil,
        isEnabled: Bool = true,
        isInFlight: Bool = false,
        action: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.inFlightTitle = inFlightTitle
        self.accessibilityLabel = accessibilityLabel
        self.isEnabled = isEnabled
        self.isInFlight = isInFlight
        self.action = action
    }
}
