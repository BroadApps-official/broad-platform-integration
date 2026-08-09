import SwiftUI
import UIKit

@MainActor
struct OnboardingWindowVisibilityView: UIViewRepresentable {
    typealias VisibilityValidator = @MainActor () -> Bool

    let onVisibilityChange: @MainActor (
        _ isVisible: Bool,
        _ validateCurrentVisibility: VisibilityValidator?
    ) -> Void

    func makeUIView(context: Context) -> OnboardingWindowVisibilityProbeView {
        OnboardingWindowVisibilityProbeView(
            onVisibilityChange: onVisibilityChange
        )
    }

    func updateUIView(
        _ uiView: OnboardingWindowVisibilityProbeView,
        context: Context
    ) {
        uiView.onVisibilityChange = onVisibilityChange
        uiView.reportVisibility(force: true)
    }

    static func dismantleUIView(
        _ uiView: OnboardingWindowVisibilityProbeView,
        coordinator: Void
    ) {
        uiView.onVisibilityChange(false, nil)
    }
}

@MainActor
final class OnboardingWindowVisibilityProbeView: UIView {
    var onVisibilityChange: @MainActor (
        _ isVisible: Bool,
        _ validateCurrentVisibility: OnboardingWindowVisibilityView.VisibilityValidator?
    ) -> Void

    private var lastReportedVisibility: Bool?

    init(
        onVisibilityChange: @escaping @MainActor (
            _ isVisible: Bool,
            _ validateCurrentVisibility: OnboardingWindowVisibilityView.VisibilityValidator?
        ) -> Void
    ) {
        self.onVisibilityChange = onVisibilityChange
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        startObservingVisibilityEnvironment()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        reportVisibility()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        reportVisibility()
    }

    func reportVisibility(force: Bool = false) {
        let isVisible = isCurrentlyVisible

        guard force || lastReportedVisibility != isVisible else {
            return
        }

        lastReportedVisibility = isVisible
        onVisibilityChange(
            isVisible,
            { [weak self] in
                self?.isCurrentlyVisible == true
            }
        )
    }

    private var isCurrentlyVisible: Bool {
        guard let window else {
            return false
        }

        return !window.isHidden
            && window.alpha > 0
            && window.windowScene?.activationState == .foregroundActive
    }

    private func startObservingVisibilityEnvironment() {
        let notifications: [Notification.Name] = [
            UIWindow.didBecomeVisibleNotification,
            UIWindow.didBecomeHiddenNotification,
            UIScene.didActivateNotification,
            UIScene.willDeactivateNotification
        ]

        for name in notifications {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(visibilityEnvironmentDidChange(_:)),
                name: name,
                object: nil
            )
        }
    }

    @objc
    private func visibilityEnvironmentDidChange(_: Notification) {
        reportVisibility()
    }
}
