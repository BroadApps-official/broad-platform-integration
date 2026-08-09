import Foundation

public struct OnboardingPageConfiguration: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let media: OnboardingMediaDescriptor

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        media: OnboardingMediaDescriptor
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.media = media
    }

    var isValid: Bool {
        !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            media.isValid
    }
}
