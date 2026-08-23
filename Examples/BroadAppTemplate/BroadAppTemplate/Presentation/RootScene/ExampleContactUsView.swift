import BroadCore
import BroadUIFlows
import SwiftUI
import UIKit

struct ExampleContactUsView: View {
    let request: BroadSupportEmailRequest?

    @State private var composerRequest: BroadSupportEmailRequest?
    @State private var fallback: ExampleSupportEmailFallback?
    @State private var lastAction: String?
    @State private var isShowingTemplate = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ExampleCatalogScreen(title: "Contact Us") {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTokens.Spacing.section) {
                    catalogHeader(
                        icon: "envelope.fill",
                        title: "Письмо и Online Chat — разные действия",
                        message: "Contact Us открывает системное письмо. Usedesk здесь не запускается и настраивается отдельно."
                    )

                    Text(
                        "На устройстве с настроенной почтой откроется composer "
                            + "с готовым body и очищенным support-log.txt. "
                            + "Simulator покажет понятный fallback."
                    )
                    .font(AppTokens.Font.body)
                    .foregroundStyle(AppTokens.Color.secondaryText)

                    BroadActionButton(
                        configuration: BroadActionConfiguration(
                            title: "Написать в поддержку",
                            action: openSupportEmail
                        ),
                        tint: AppTokens.Color.core
                    )
                    .accessibilityIdentifier("support.open")

                    Button("Проверить пустой support email") {
                        fallback = .missingAddress
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("support.empty")

                    if let lastAction {
                        Label(lastAction, systemImage: "checkmark.circle.fill")
                            .font(AppTokens.Font.caption)
                            .foregroundStyle(AppTokens.Color.success)
                    }

                    if let request {
                        DisclosureGroup(
                            "Предпросмотр подготовленного fixture-письма",
                            isExpanded: $isShowingTemplate
                        ) {
                            Text(request.body)
                                .font(AppTokens.Font.fixtureCode)
                                .textSelection(.enabled)
                                .padding(.top, AppTokens.Spacing.small)
                            Label(
                                "Прикрепляется \(request.supportLogFileName)",
                                systemImage: "doc.badge.plus"
                            )
                            .font(AppTokens.Font.caption)
                            .foregroundStyle(AppTokens.Color.secondaryText)
                        }
                        .font(AppTokens.Font.cardTitle)
                        .tint(AppTokens.Color.accent)
                    }
                }
                .padding(AppTokens.Spacing.screenHorizontal)
            }
        }
        .sheet(item: $composerRequest) { request in
            BroadSupportEmailComposer(request: request) { result in
                composerRequest = nil
                lastAction = result.message
            }
        }
        .alert(
            fallback?.title ?? "",
            isPresented: isShowingFallback,
            presenting: fallback
        ) { fallback in
            if let address = fallback.address {
                Button("Скопировать адрес") {
                    UIPasteboard.general.string = address
                    lastAction = "Адрес поддержки скопирован."
                }
                .accessibilityIdentifier("support.copy")
            }
            if let externalURL = fallback.externalURL {
                Button("Открыть внешнюю почту") {
                    openURL(externalURL)
                    lastAction = "Передали адрес внешнему почтовому приложению."
                }
            }
            Button("Закрыть", role: .cancel) {}
        } message: { fallback in
            Text(fallback.message)
        }
    }

    private var isShowingFallback: Binding<Bool> {
        Binding(
            get: { fallback != nil },
            set: { isPresented in
                if !isPresented {
                    fallback = nil
                }
            }
        )
    }

    private func openSupportEmail() {
        guard let request else {
            fallback = .missingAddress
            return
        }
        guard BroadSupportEmailComposer.canSendMail else {
            let externalURL = request.externalComposeURL.flatMap { url in
                UIApplication.shared.canOpenURL(url) ? url : nil
            }
            fallback = .mailUnavailable(
                address: request.recipient,
                externalURL: externalURL
            )
            return
        }

        composerRequest = request
    }
}

private enum ExampleSupportEmailFallback: Identifiable {
    case mailUnavailable(address: String, externalURL: URL?)
    case missingAddress

    var id: String {
        switch self {
        case let .mailUnavailable(address, _):
            "mail-unavailable-\(address)"
        case .missingAddress:
            "missing-address"
        }
    }

    var title: String {
        switch self {
        case .mailUnavailable:
            "Почта не настроена"
        case .missingAddress:
            "Адрес поддержки не настроен"
        }
    }

    var message: String {
        switch self {
        case let .mailUnavailable(address, externalURL):
            if externalURL == nil {
                return "Скопируйте адрес \(address) и напишите из любого почтового приложения."
            }
            return "Скопируйте адрес \(address) или откройте доступное почтовое приложение."
        case .missingAddress:
            return "Добавьте support email в конфигурацию приложения. Экран не будет открыт с пустым получателем."
        }
    }

    var address: String? {
        switch self {
        case let .mailUnavailable(address, _): address
        case .missingAddress: nil
        }
    }

    var externalURL: URL? {
        switch self {
        case let .mailUnavailable(_, externalURL): externalURL
        case .missingAddress: nil
        }
    }
}

private extension BroadSupportEmailComposerResult {
    var message: String {
        switch self {
        case .cancelled: "Письмо не отправлено."
        case .saved: "Черновик письма сохранён."
        case .sent: "Письмо передано почтовому приложению."
        case .failed: "Почтовое приложение сообщило об ошибке."
        }
    }
}
