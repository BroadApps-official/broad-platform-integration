import SwiftUI
import UIKit

public struct BroadRGBAColor: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init?(hex: String) {
        let normalized = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard [3, 4, 6, 8].contains(normalized.count),
              normalized.allSatisfy(\.isHexDigit),
              let value = UInt64(normalized, radix: 16)
        else {
            return nil
        }

        let channels: BroadColorChannels
        switch normalized.count {
        case 3:
            channels = BroadColorChannels(
                red: ((value >> 8) & 0xF) * 17,
                green: ((value >> 4) & 0xF) * 17,
                blue: (value & 0xF) * 17,
                alpha: 255
            )
        case 4:
            channels = BroadColorChannels(
                red: ((value >> 12) & 0xF) * 17,
                green: ((value >> 8) & 0xF) * 17,
                blue: ((value >> 4) & 0xF) * 17,
                alpha: (value & 0xF) * 17
            )
        case 6:
            channels = BroadColorChannels(
                red: (value >> 16) & 0xFF,
                green: (value >> 8) & 0xFF,
                blue: value & 0xFF,
                alpha: 255
            )
        case 8:
            channels = BroadColorChannels(
                red: (value >> 24) & 0xFF,
                green: (value >> 16) & 0xFF,
                blue: (value >> 8) & 0xFF,
                alpha: value & 0xFF
            )
        default:
            return nil
        }

        red = Double(channels.red) / 255
        green = Double(channels.green) / 255
        blue = Double(channels.blue) / 255
        alpha = Double(channels.alpha) / 255
    }
}

private struct BroadColorChannels {
    let red: UInt64
    let green: UInt64
    let blue: UInt64
    let alpha: UInt64
}

public extension Color {
    init?(broadHex: String) {
        guard let rgba = BroadRGBAColor(hex: broadHex) else {
            return nil
        }
        self.init(
            .sRGB,
            red: rgba.red,
            green: rgba.green,
            blue: rgba.blue,
            opacity: rgba.alpha
        )
    }
}

public extension UIColor {
    convenience init?(broadHex: String) {
        guard let rgba = BroadRGBAColor(hex: broadHex) else {
            return nil
        }
        self.init(
            red: rgba.red,
            green: rgba.green,
            blue: rgba.blue,
            alpha: rgba.alpha
        )
    }
}
