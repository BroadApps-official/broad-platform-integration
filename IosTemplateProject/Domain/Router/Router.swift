
import SwiftUI
import Combine

final class Router: ObservableObject {
    private var navigationStack: [Pages] = []
    @Published var isShowLeftReviewRequestView: Bool = false
    @Published var isShowingCameraPicker: Bool = false
    @Published var isShowingCameraPickerForTextScan: Bool = false
    @Published var isShowingCameraPickerForPaintChat: Bool = false
    @Published var isShowingGalleryPicker: Bool = false
    @Published var isShowingGalleryPickerForTextScan: Bool = false
    @Published var isShowingGalleryPickerForPaintChat: Bool = false
    @Published var isShowingSpecialPrivacySheet: Bool = false

    @Published var path: NavigationPath = NavigationPath()
    @Published var selectedTab: Int = 0
    @Published var currentPage: Pages = .loader
    @Published var transition: AnyTransition = .move(edge: .trailing)
    
    enum AnimationEnum {
        case fromLeading
        case fromTrailing
        case smooth
        case fromBottom
        case throughToRight
    }
    enum Pages {
//        case tabView
        case onboarding
        case loader
        case main
//        case paywallAfterOnboarding
    }
}

extension Router {
    func popToRoot() {
        path = NavigationPath()
    }
    
    func navigateTo(_ page: Pages, with animation: AnimationEnum) {
        navigationStack.append(currentPage)
        
        switch animation {
        case .fromLeading:
            transition = .move(edge: .leading)
        case .fromTrailing:
            transition = .move(edge: .trailing)
        case .fromBottom:
            transition = .move(edge: .bottom)
        case .smooth:
            transition = .opacity
        case .throughToRight:
            transition = .push(from: .trailing)
        }
        currentPage = page
    }
}
