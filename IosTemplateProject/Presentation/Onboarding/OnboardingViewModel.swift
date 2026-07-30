import SwiftUI
import Combine
import StoreKit

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentPage: Int = 0
    @Published var pages: [OnboardingPageModel] = []
    @Published var surveyOptions: [OnboardingSurveyOption] = []
    @Published var surveyAnswer: String?
    @Published var isShowingReviewRequest: Bool = false

    /// Индекс survey-страницы (кнопка Next неактивна, пока нет ответа).
    /// Поставь `nil`, если survey не нужен.
    let surveyPageIndex: Int? = 3

    var isOnSurveyPage: Bool {
        guard let surveyPageIndex else { return false }
        return currentPage == surveyPageIndex
    }

    var canProceed: Bool {
        guard isOnSurveyPage else { return true }
        return surveyAnswer != nil
    }

    var isLastPage: Bool {
        currentPage >= pages.count - 1
    }

    init() {
        loadPages()
        loadSurveyOptions()
    }

    func nextPage() {
        guard currentPage < pages.count - 1 else { return }
        currentPage += 1
    }

    func previousPage() {
        guard currentPage > 0 else { return }
        currentPage -= 1
    }

    func requestAppReview() {
        guard !isShowingReviewRequest else { return }
        isShowingReviewRequest = true

        Task { @MainActor in
            let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
                ?? UIApplication.shared.connectedScenes.first as? UIWindowScene

            guard let windowScene else { return }
            AppStore.requestReview(in: windowScene)
        }
    }
}

// MARK: - Replaceable content
extension OnboardingViewModel {
    /// ✏️ Сюда подставляй тексты, картинки и кнопки под новый проект.
    /// `imageName` — имя imageset в Assets (пустая строка = без картинки).
    private func loadPages() {
        pages = [
            OnboardingPageModel(
                imageName: "onboard_1",
                title: "Welcome to your app",
                buttonTitle: "Continue"
            ),
            OnboardingPageModel(
                imageName: "onboard_2",
                title: "Create amazing results in seconds",
                buttonTitle: "Continue"
            ),
            OnboardingPageModel(
                imageName: "onboard_3",
                title: "Save and share your favorites",
                buttonTitle: "Continue"
            ),
            OnboardingPageModel(
                imageName: "",
                title: "What brings you here?",
                buttonTitle: "Continue"
            ),
            OnboardingPageModel(
                imageName: "onboard_4",
                title: "You're all set — let's start",
                buttonTitle: "Get Started"
            )
        ]
    }

    /// ✏️ Варианты survey. Иконки — SF Symbols.
    private func loadSurveyOptions() {
        surveyOptions = [
            OnboardingSurveyOption(systemImage: "person.crop.rectangle.stack", title: "Try new styles"),
            OnboardingSurveyOption(systemImage: "face.smiling", title: "Have fun"),
            OnboardingSurveyOption(systemImage: "highlighter", title: "Edit photos"),
            OnboardingSurveyOption(systemImage: "bolt", title: "Fast results"),
            OnboardingSurveyOption(systemImage: "lasso.sparkles", title: "Just exploring")
        ]
    }
}
