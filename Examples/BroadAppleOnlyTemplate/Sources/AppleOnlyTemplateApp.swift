import SwiftUI

@main
struct AppleOnlyTemplateApp: App {
    var body: some Scene {
        WindowGroup { NavigationStack { FixturePaywallScreen(showsSpecialOffer: false) } }
    }
}
