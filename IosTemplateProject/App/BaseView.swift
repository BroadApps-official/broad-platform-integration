

import SwiftUI


struct BaseView: View {
    @StateObject var router = Router()
    @StateObject var onboardingVM = OnboardingViewModel()
    
    var body: some View {
        ZStack {
            switch router.currentPage {
            case .loader:
                LoaderView()
                    .zIndex(0)
            case .onboarding:
                OnboardingView(viewModel: onboardingVM)
                    .transition(router.transition)
                    .zIndex(0)
            case .main:
                ContentView()
                    .transition(router.transition)
                    .zIndex(0)
//            case .paywallAfterOnboarding:
//                SubscriptionView(
//                    closeAction: {
//                        DispatchQueue.main.async {
//                            router.navigateTo(.main, with: .fromLeading)
//                        }
//                    }
//                )
//                .transition(router.transition)
//                .zIndex(0)
//            case .tabView:
//                MainTabView()
//                .transition(router.transition)
//                .zIndex(0)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: router.currentPage)
        .environmentObject(router)
        .background(.specialFon)
    }
}
