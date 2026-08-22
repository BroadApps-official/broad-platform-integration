import SwiftUI

/// Actions shared by the standard onboarding renderer and app-owned renderers.
/// The host keeps completion and ATT lifecycle rules outside visual code.
@MainActor
public struct OnboardingFlowActions {
    private let advanceAction: @MainActor () -> Void

    init(advance: @escaping @MainActor () -> Void) {
        advanceAction = advance
    }

    /// Advances to the next configured page or completes the onboarding when
    /// the current page is the last one.
    public func advance() {
        advanceAction()
    }
}

/// A logic-only onboarding host for applications with a fully custom design.
///
/// It owns lifecycle, window visibility, invalid configuration handling and
/// the safe ATT boundary. The `content` closure owns every visual decision.
@MainActor
public struct BroadOnboardingFlowHost<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var viewModel: OnboardingViewModel

    private let onCompleted: @MainActor () -> Void
    private let content: @MainActor (
        OnboardingViewModel,
        OnboardingFlowActions
    ) -> Content

    public init(
        viewModel: OnboardingViewModel,
        onCompleted: @escaping @MainActor () -> Void,
        @ViewBuilder content: @escaping @MainActor (
            OnboardingViewModel,
            OnboardingFlowActions
        ) -> Content
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onCompleted = onCompleted
        self.content = content
    }

    public var body: some View {
        Group {
            if viewModel.configuration.isValid {
                content(
                    viewModel,
                    OnboardingFlowActions(advance: advance)
                )
            } else {
                Color.clear
                    .accessibilityHidden(true)
            }
        }
        .background(windowVisibilityObserver)
        .onAppear {
            viewModel.onboardingDidAppear()
            viewModel.applicationActiveDidChange(scenePhase == .active)
            markFirstPageVisibleIfNeeded()

            if viewModel.completeInvalidConfigurationIfNeeded() {
                onCompleted()
            }
        }
        .onDisappear {
            viewModel.onboardingDidDisappear()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            viewModel.applicationActiveDidChange(phase == .active)
        }
        .onChange(of: viewModel.currentIndex) { previousIndex, currentIndex in
            let firstIndex = viewModel.configuration.pages.startIndex
            if previousIndex == firstIndex, currentIndex != firstIndex {
                viewModel.firstSlideDidDisappear()
            }
            if currentIndex == firstIndex {
                viewModel.firstSlideDidAppear()
            }
        }
    }

    private var windowVisibilityObserver: some View {
        OnboardingWindowVisibilityView { isVisible, validateCurrentVisibility in
            viewModel.windowVisibilityDidChange(
                isVisible,
                validateCurrentVisibility: validateCurrentVisibility
            )
        }
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func markFirstPageVisibleIfNeeded() {
        guard viewModel.currentIndex == viewModel.configuration.pages.startIndex else {
            return
        }
        viewModel.firstSlideDidAppear()
    }

    private func advance() {
        if viewModel.advance() {
            onCompleted()
        }
    }
}
