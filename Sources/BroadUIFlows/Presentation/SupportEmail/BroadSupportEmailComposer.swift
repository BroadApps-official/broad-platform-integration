@preconcurrency import MessageUI
import SwiftUI

public enum BroadSupportEmailComposerResult: Equatable, Sendable {
    case cancelled
    case saved
    case sent
    case failed
}

public struct BroadSupportEmailComposer: UIViewControllerRepresentable {
    private let request: BroadSupportEmailRequest
    private let onFinish: (BroadSupportEmailComposerResult) -> Void

    public init(
        request: BroadSupportEmailRequest,
        onFinish: @escaping (BroadSupportEmailComposerResult) -> Void
    ) {
        self.request = request
        self.onFinish = onFinish
    }

    @MainActor
    public static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    public func makeUIViewController(
        context: Context
    ) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([request.recipient])
        composer.setSubject(request.subject)
        composer.setMessageBody(request.body, isHTML: false)
        composer.addAttachmentData(
            request.supportLogData,
            mimeType: "text/plain",
            fileName: request.supportLogFileName
        )
        return composer
    }

    public func updateUIViewController(
        _ uiViewController: MFMailComposeViewController,
        context: Context
    ) {}

    @MainActor
    public final class Coordinator: NSObject, @preconcurrency MFMailComposeViewControllerDelegate {
        private let onFinish: (BroadSupportEmailComposerResult) -> Void

        init(
            onFinish: @escaping (BroadSupportEmailComposerResult) -> Void
        ) {
            self.onFinish = onFinish
        }

        public func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            let mappedResult: BroadSupportEmailComposerResult = if error != nil {
                .failed
            } else {
                switch result {
                case .cancelled: .cancelled
                case .saved: .saved
                case .sent: .sent
                case .failed: .failed
                @unknown default: .failed
                }
            }
            controller.dismiss(animated: true) {
                self.onFinish(mappedResult)
            }
        }
    }
}
