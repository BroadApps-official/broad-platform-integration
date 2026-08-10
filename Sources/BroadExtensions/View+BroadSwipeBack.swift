import SwiftUI
import UIKit

public extension View {
    /// Restores the system edge-swipe when a destination uses custom navigation
    /// chrome. The bridge is scoped to the hosting navigation controller and
    /// restores its previous gesture delegate when the destination disappears.
    func broadInteractiveSwipeBack() -> some View {
        background(BroadInteractivePopBridge())
    }
}

private struct BroadInteractivePopBridge: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> BridgeViewController {
        BridgeViewController(coordinator: context.coordinator)
    }

    func updateUIViewController(
        _ uiViewController: BridgeViewController,
        context _: Context
    ) {
        uiViewController.installIfPossible()
    }

    static func dismantleUIViewController(
        _ uiViewController: BridgeViewController,
        coordinator _: Coordinator
    ) {
        uiViewController.restore()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?
        weak var previousDelegate: (any UIGestureRecognizerDelegate)?

        func gestureRecognizerShouldBegin(
            _ gestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            guard let navigationController,
                  navigationController.viewControllers.count > 1
            else {
                return false
            }

            return previousDelegate?.gestureRecognizerShouldBegin?(
                gestureRecognizer
            ) ?? true
        }
    }

    final class BridgeViewController: UIViewController {
        private let coordinator: Coordinator

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(nibName: nil, bundle: nil)
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            installIfPossible()
        }

        func installIfPossible() {
            guard let navigationController,
                  let gesture = navigationController.interactivePopGestureRecognizer
            else {
                return
            }

            if coordinator.navigationController !== navigationController {
                restore()
                coordinator.navigationController = navigationController
                coordinator.previousDelegate = gesture.delegate
            }
            gesture.delegate = coordinator
            gesture.isEnabled = navigationController.viewControllers.count > 1
        }

        func restore() {
            guard let navigationController = coordinator.navigationController,
                  let gesture = navigationController.interactivePopGestureRecognizer,
                  gesture.delegate === coordinator
            else {
                coordinator.navigationController = nil
                coordinator.previousDelegate = nil
                return
            }

            gesture.delegate = coordinator.previousDelegate
            coordinator.navigationController = nil
            coordinator.previousDelegate = nil
        }
    }
}
