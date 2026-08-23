import BroadCore
import BroadMonetization
import BroadUIFlows
import Foundation

enum RootModuleKind: Equatable, Sendable {
    case core
    case monetization
    case uiFlows
}

enum BootstrapStatusCardState: Equatable {
    case loading(title: String, message: String)
    case ready(title: String, message: String)
    case degraded(title: String, message: String)
    case failed(title: String, message: String, retryTitle: String?)
}

@MainActor
final class RootViewModel: ObservableObject {
    struct Content {
        let eyebrow: String
        let title: String
        let subtitle: String
        let coreDescription: String
        let monetizationDescription: String
        let uiFlowsDescription: String
        let connectedDetail: String
        let adaptyLinkedDetail: String
        let adaptyUnavailableDetail: String
        let loadingTitle: String
        let loadingMessage: String
        let readyTitle: String
        let readyMessage: String
        let degradedTitle: String
        let degradedMessage: String
        let failedTitle: String
        let retryTitle: String
    }

    struct ModuleItem: Equatable, Identifiable, Sendable {
        let id: String
        let title: String
        let description: String
        let systemImage: String
        let kind: RootModuleKind
        let detail: String
    }

    let content: Content

    @Published private(set) var moduleState: LoadableState<[ModuleItem]>
    @Published private(set) var bootstrapStatusCardState: BootstrapStatusCardState

    private let runAppBootstrapUseCase: any RunAppBootstrapUseCaseProtocol
    private let appFlowCoordinator: AppFlowCoordinator
    private let moduleSnapshot: [ModuleItem]
    private var bootstrapTask: Task<Void, Never>?
    private var stateObservationTask: Task<Void, Never>?
    private var didStartBootstrap = false

    init(
        content: Content,
        coreModule: BroadCoreModule,
        monetizationModule: BroadMonetizationModule,
        uiFlowsModule: BroadUIFlowsModule,
        runAppBootstrapUseCase: any RunAppBootstrapUseCaseProtocol,
        appFlowCoordinator: AppFlowCoordinator
    ) {
        self.content = content
        self.runAppBootstrapUseCase = runAppBootstrapUseCase
        self.appFlowCoordinator = appFlowCoordinator
        let moduleSnapshot = [
            ModuleItem(
                id: coreModule.identifier,
                title: coreModule.identifier,
                description: content.coreDescription,
                systemImage: "shippingbox.fill",
                kind: .core,
                detail: content.connectedDetail
            ),
            ModuleItem(
                id: monetizationModule.identifier,
                title: monetizationModule.identifier,
                description: content.monetizationDescription,
                systemImage: "creditcard.fill",
                kind: .monetization,
                detail: monetizationModule.isAdaptyLinked ? content.adaptyLinkedDetail : content.adaptyUnavailableDetail
            ),
            ModuleItem(
                id: uiFlowsModule.identifier,
                title: uiFlowsModule.identifier,
                description: content.uiFlowsDescription,
                systemImage: "rectangle.3.group.fill",
                kind: .uiFlows,
                detail: content.connectedDetail
            )
        ]
        self.moduleSnapshot = moduleSnapshot
        moduleState = .idle
        bootstrapStatusCardState = .loading(
            title: content.loadingTitle,
            message: content.loadingMessage
        )
    }

    deinit {
        bootstrapTask?.cancel()
        stateObservationTask?.cancel()
    }

    func startIfNeeded() {
        guard !didStartBootstrap else {
            return
        }

        didStartBootstrap = true
        observeBootstrapState()
        runBootstrap()
    }

    func retry() {
        guard case let .error(error, _) = moduleState, error.isRetryable else {
            return
        }

        moduleState = moduleState.beginLoading()
        bootstrapStatusCardState = .loading(
            title: content.loadingTitle,
            message: content.loadingMessage
        )
        bootstrapTask?.cancel()
        bootstrapTask = Task { [weak self] in
            guard let self else {
                return
            }

            await runAppBootstrapUseCase.retry()
        }
    }

    private func runBootstrap() {
        bootstrapTask = Task { [weak self] in
            guard let self else {
                return
            }

            await runAppBootstrapUseCase()
        }
    }

    private func observeBootstrapState() {
        stateObservationTask = Task { [weak self, runAppBootstrapUseCase] in
            let states = await runAppBootstrapUseCase.states()
            for await state in states {
                guard !Task.isCancelled else {
                    return
                }

                self?.apply(state)
            }
        }
    }

    private func apply(_ state: AppBootstrapState) {
        switch state {
        case .idle:
            moduleState = .idle
            bootstrapStatusCardState = .loading(
                title: content.loadingTitle,
                message: content.loadingMessage
            )
        case .starting:
            moduleState = moduleState.beginLoading()
            bootstrapStatusCardState = .loading(
                title: content.loadingTitle,
                message: content.loadingMessage
            )
        case .ready:
            moduleState = .loaded(moduleSnapshot)
            bootstrapStatusCardState = .ready(
                title: content.readyTitle,
                message: content.readyMessage
            )
            appFlowCoordinator.startIfNeeded()
        case .degraded:
            moduleState = .loaded(moduleSnapshot)
            bootstrapStatusCardState = .degraded(
                title: content.degradedTitle,
                message: content.degradedMessage
            )
            appFlowCoordinator.startIfNeeded()
        case let .failed(error):
            moduleState = moduleState.fail(with: error)
            bootstrapStatusCardState = .failed(
                title: content.failedTitle,
                message: error.userMessage,
                retryTitle: error.isRetryable ? content.retryTitle : nil
            )
        }
    }
}

extension RootViewModel.Content {
    init(configuration: AppConfiguration.RootContent) {
        self.init(
            eyebrow: configuration.eyebrow,
            title: configuration.title,
            subtitle: configuration.subtitle,
            coreDescription: configuration.coreDescription,
            monetizationDescription: configuration.monetizationDescription,
            uiFlowsDescription: configuration.uiFlowsDescription,
            connectedDetail: configuration.connectedDetail,
            adaptyLinkedDetail: configuration.adaptyLinkedDetail,
            adaptyUnavailableDetail: configuration.adaptyUnavailableDetail,
            loadingTitle: configuration.loadingTitle,
            loadingMessage: configuration.loadingMessage,
            readyTitle: configuration.readyTitle,
            readyMessage: configuration.readyMessage,
            degradedTitle: configuration.degradedTitle,
            degradedMessage: configuration.degradedMessage,
            failedTitle: configuration.failedTitle,
            retryTitle: configuration.retryTitle
        )
    }
}
