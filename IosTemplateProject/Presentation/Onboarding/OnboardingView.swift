import SwiftUI

struct OnboardingView: View {
    @AppStorage(AppConstants.isOnboardingReviewed) private var isOnboardingReviewed = false
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject var router: Router

    var body: some View {
        ZStack {
            bottomContent
                .padding(.horizontal, 16)
                .opacity(isOnboardingReviewed ? 0 : 1)
                .animation(.easeInOut(duration: 0.5), value: isOnboardingReviewed)
        }
        .background {
            pagesBackground
                .opacity(isOnboardingReviewed ? 0 : 1)
                .animation(.easeInOut(duration: 0.5), value: isOnboardingReviewed)
        }
    }

    // MARK: - Bottom content

    private var bottomContent: some View {
        VStack(alignment: .leading) {
            if viewModel.isOnSurveyPage {
                surveySubview
            }

            Spacer()

            if !viewModel.isOnSurveyPage {
                titleText
            }

            OnboardingPageControl(
                selectedPage: viewModel.currentPage,
                pageCount: viewModel.pages.count
            )
            .padding(.bottom, 24)

            OnboardingNextButton(
                title: currentPageModel?.buttonTitle ?? "Continue",
                isEnabled: viewModel.canProceed,
                action: handleNextTap
            )
            .padding(.bottom, 12)

            OnboardingLinksRow(
                termsURL: URL(string: AppConstants.termsOfUseURL) ?? URL(string: "https://example.com")!,
                privacyURL: URL(string: AppConstants.privacyPolicyURL) ?? URL(string: "https://example.com")!,
                restoreAction: {
                    // Hook restore purchases when StoreKit / Adapty is ready.
                }
            )
        }
    }

    private var titleText: some View {
        Text(currentPageModel?.title ?? "")
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(.specialWhite)
            .lineLimit(3)
            .multilineTextAlignment(viewModel.isOnSurveyPage ? .center : .leading)
            .minimumScaleFactor(0.7)
            .padding(.bottom, 20)
    }

    private var surveySubview: some View {
        VStack {
            titleText
                .padding(.top, 28)
                .padding(.bottom, 20)

            VStack(spacing: 8) {
                ForEach(viewModel.surveyOptions) { option in
                    OnboardingSurveyButton(
                        systemImage: option.systemImage,
                        title: option.title,
                        isSelected: viewModel.surveyAnswer == option.title
                    ) {
                        viewModel.surveyAnswer = option.title
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Background pages

    private var pagesBackground: some View {
        VStack {
            horizontalPagesGrid
            Spacer()
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .specialFon],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(height: UIScreen.main.bounds.height * 0.37)
                .ignoresSafeArea()
        }
    }

    private var horizontalPagesGrid: some View {
        let modelArray = viewModel.pages

        return GeometryReader { geometry in
            let screenWidth = geometry.size.width

            if modelArray.isEmpty {
                Text("No onboarding data available")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    ForEach(modelArray) { item in
                        pageImage(item, width: screenWidth)
                            .frame(width: screenWidth)
                    }
                }
                .frame(width: screenWidth * CGFloat(modelArray.count), alignment: .leading)
                .offset(x: -CGFloat(viewModel.currentPage) * screenWidth)
                .animation(.spring(), value: viewModel.currentPage)
            }
        }
    }

    @ViewBuilder
    private func pageImage(_ item: OnboardingPageModel, width: CGFloat) -> some View {
        if item.imageName.isEmpty {
            Color.clear
                .frame(width: width)
        } else if UIImage(named: item.imageName) != nil {
            ScrollView(.vertical, showsIndicators: false) {
                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width)
            }
            .scrollDisabled(true)
        } else {
            // Placeholder until real assets are added to Assets.xcassets
            ZStack {
                Color.specialFon
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(.specialWhite.opacity(0.35))
                    Text(item.imageName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.specialWhite.opacity(0.35))
                }
            }
            .frame(width: width, height: UIScreen.main.bounds.height * 0.55)
        }
    }

    // MARK: - Actions

    private var currentPageModel: OnboardingPageModel? {
        guard viewModel.pages.indices.contains(viewModel.currentPage) else { return nil }
        return viewModel.pages[viewModel.currentPage]
    }

    private func handleNextTap() {
        if viewModel.isLastPage {
            finishOnboarding()
        } else {
            withAnimation {
                viewModel.nextPage()
            }
        }
    }

    private func finishOnboarding() {
        isOnboardingReviewed = true
        // TODO: router.navigateTo(.paywallAfterOnboarding, with: .fromTrailing)
        router.navigateTo(.main, with: .fromTrailing)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            viewModel.requestAppReview()
        }
    }
}

#Preview {
    OnboardingView(viewModel: OnboardingViewModel())
        .environmentObject(Router())
        .background(Color.specialFon)
}
