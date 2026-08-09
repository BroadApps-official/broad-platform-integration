import SwiftUI
import UIKit

@MainActor
private enum LayoutScale {
    static var factor: CGFloat {
        let referenceWidth: CGFloat = 393
        let rawFactor = UIScreen.main.bounds.width / referenceWidth
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
