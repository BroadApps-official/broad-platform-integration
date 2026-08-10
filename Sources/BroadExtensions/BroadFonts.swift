import CoreText
import SwiftUI
import UIKit

public enum BroadFontRegistrationError: Error, Equatable, Sendable {
    case resourceNotFound(String)
    case registrationFailed(String)
}

public enum BroadFontRegistrar {
    public static func register(
        resourceNames: [String],
        withExtension resourceExtension: String,
        in bundle: Bundle = .main
    ) throws {
        for resourceName in resourceNames {
            guard let url = bundle.url(
                forResource: resourceName,
                withExtension: resourceExtension
            ) else {
                throw BroadFontRegistrationError.resourceNotFound(
                    "\(resourceName).\(resourceExtension)"
                )
            }

            var unmanagedError: Unmanaged<CFError>?
            let registered = CTFontManagerRegisterFontsForURL(
                url as CFURL,
                .process,
                &unmanagedError
            )
            guard registered || isAlreadyRegistered(unmanagedError) else {
                throw BroadFontRegistrationError.registrationFailed(resourceName)
            }
        }
    }

    private static func isAlreadyRegistered(
        _ error: Unmanaged<CFError>?
    ) -> Bool {
        guard let error else {
            return false
        }
        return CFErrorGetCode(error.takeRetainedValue())
            == CTFontManagerError.alreadyRegistered.rawValue
    }
}

public extension Font {
    static func broadCustom(
        _ name: String,
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        .custom(name, size: size, relativeTo: textStyle)
    }
}

public extension UIFont {
    static func broadCustom(
        _ name: String,
        size: CGFloat,
        textStyle: UIFont.TextStyle = .body
    ) -> UIFont? {
        guard let font = UIFont(name: name, size: size) else {
            return nil
        }
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font)
    }
}
