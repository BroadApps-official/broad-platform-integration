
import SwiftUI


struct LoaderView: View {
    @EnvironmentObject var router: Router
    
    var body: some View {
        mainView
            .task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    if UserDefaults.standard.bool(forKey: AppConstants.isOnboardingReviewed) {
                        router.navigateTo(.main, with: .throughToRight)
                    } else {
                        router.navigateTo(.onboarding, with: .throughToRight)
                    }
                }
            }
    }
    
    private var mainView: some View {
        ZStack {
            Color.specialFon.ignoresSafeArea(edges: .all)
            
            Image(.loaderIcon)
                .resizable()
                .scaledToFill()
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            
            VStack {
                Spacer()
                
                ProgressView()
                    .scaleEffect(2.0)
                    .tint(Color.white)
            }
            .padding(.bottom, 36)
        }
    }
}


#Preview {
    LoaderView()
        .environmentObject(Router())
}
