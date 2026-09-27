import SwiftUI
import UIKit

@MainActor
private enum LayoutScale {
    /// Width of the device the Figma layout is drawn for; 393 when there is no Figma.
    static let designWidth: CGFloat = 393

    static var factor: CGFloat {
        let rawFactor = UIScreen.main.bounds.width / designWidth
        return min(max(rawFactor, 0.85), 1.25)
    }
}

extension CGFloat {
    @MainActor
    var scale: CGFloat {
        self * LayoutScale.factor
    }
}

extension Double {
    @MainActor
    var scale: CGFloat {
        CGFloat(self).scale
    }
}

extension Int {
    @MainActor
    var scale: CGFloat {
        CGFloat(self).scale
    }
}
