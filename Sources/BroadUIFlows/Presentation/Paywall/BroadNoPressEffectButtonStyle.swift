import SwiftUI

/// Keeps the label visually identical while a finger is down.
/// Selection and in-flight state must be expressed by explicit content, never by dimming.
public struct BroadNoPressEffectButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
