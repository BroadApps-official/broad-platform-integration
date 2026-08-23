import Foundation

public enum BroadSupportEmailRequestBuilder {
    public static func makeRequest(
        configuration: BroadSupportEmailConfiguration
    ) -> BroadSupportEmailRequest? {
        let recipient = configuration.recipient.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let attachmentName = configuration.supportLogFileName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !recipient.isEmpty,
              !configuration.supportLogData.isEmpty,
              !attachmentName.isEmpty
        else {
            return nil
        }

        return BroadSupportEmailRequest(
            recipient: recipient,
            subject: configuration.subject,
            body: makeBody(configuration: configuration),
            supportLogData: configuration.supportLogData,
            supportLogFileName: attachmentName
        )
    }

    private static func makeBody(
        configuration: BroadSupportEmailConfiguration
    ) -> String {
        """
        \(configuration.greeting.text)

        --- App info ---
        App: \(configuration.appName)
        Version: \(configuration.appStoreVersion) (App Store)
        Installed: \(configuration.installedVersion) (\(configuration.buildNumber))
        Bundle: \(configuration.bundleIdentifier)

        --- Device ---
        System: iOS \(configuration.systemVersion)
        Device: \(configuration.deviceModel)
        Locale: \(configuration.localeIdentifier)
        TimeZone: \(configuration.timeZoneIdentifier)

        --- IDs ---
        Adapty profileID: \(configuration.adaptyProfileID)
        Backend userID: \(configuration.backendUserID)
        Subscription: \(configuration.subscriptionStatus)

        --- Diagnostics ---
        A support log is attached.

        --- Describe the problem below ---

        """
    }
}
