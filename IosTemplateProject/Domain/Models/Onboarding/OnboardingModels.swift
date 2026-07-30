import Foundation

/// Одна страница онбординга.
/// Замени `imageName` на имя ассета из Assets; пустая строка — страница без картинки (например, survey).
struct OnboardingPageModel: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
    let buttonTitle: String
}

/// Вариант ответа на survey-странице.
struct OnboardingSurveyOption: Identifiable {
    let id = UUID()
    /// SF Symbol name
    let systemImage: String
    let title: String
}
