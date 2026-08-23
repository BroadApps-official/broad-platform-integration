import BroadMonetization
import Combine

@MainActor
public final class AppFlowCoordinator: ObservableObject {
    @Published public private(set) var route: AppFlowRoute = .launch
    @Published public private(set) var isTransitionInFlight = false

    private let configuration: AppFlowConfiguration
    private let progressRepository: any AppFlowProgressRepositoryProtocol
    private let entitlementStatusProvider: any EntitlementStatusProviderProtocol

    private var stateMachine: AppFlowStateMachine
    private var transitionTask: Task<Void, Never>?
    private var transitionGeneration: UInt64 = 0
    private var transitionCheckpoint: AppFlowCheckpoint?
    private var didStart = false
    private var hasConfirmedActiveEntitlement = false

    public init(
        configuration: AppFlowConfiguration,
        progressRepository: any AppFlowProgressRepositoryProtocol,
        entitlementStatusProvider: any EntitlementStatusProviderProtocol
    ) {
        self.configuration = configuration
        self.progressRepository = progressRepository
        self.entitlementStatusProvider = entitlementStatusProvider
        stateMachine = AppFlowStateMachine(configuration: configuration)
    }

    deinit {
        transitionTask?.cancel()
    }

    public func startIfNeeded() {
        guard !didStart else {
            return
        }

        didStart = true

        guard configuration.requiresStoredProgress else {
            route = stateMachine.resolve(
                checkpoint: .start,
                entitlementStatus: nil
            )
            return
        }

        let generation = beginTransition()
        let repository = progressRepository
        let provider = entitlementStatusProvider

        transitionTask = Task { @MainActor [weak self, repository, provider] in
            let checkpoint = await repository.loadCheckpoint()
            guard let self, isCurrent(generation) else {
                return
            }

            await resolve(
                checkpoint: checkpoint,
                provider: provider,
                generation: generation
            )
        }
    }

    public func onboardingCompleted() {
        guard route == .onboarding, !isTransitionInFlight else {
            return
        }

        let generation = beginTransition()
        let repository = progressRepository
        let provider = entitlementStatusProvider

        transitionTask = Task { @MainActor [weak self, repository, provider] in
            let checkpoint = await repository.advance(to: .onboardingCompleted)
            guard let self, isCurrent(generation) else {
                return
            }

            await resolve(
                checkpoint: checkpoint,
                provider: provider,
                generation: generation
            )
        }
    }

    public func subscriptionDidBecomeActive() {
        let wasAlreadyConfirmed = hasConfirmedActiveEntitlement
        hasConfirmedActiveEntitlement = true

        switch route {
        case .launch, .onboarding:
            resolveInFlightTransitionWithConfirmedActiveEntitlement()
        case .initialPaywall:
            cancelTransition()
            route = stateMachine.subscriptionDidBecomeActive()
            persistResolvedPaywallIfNeeded()
        case .main:
            if !wasAlreadyConfirmed {
                persistResolvedPaywallIfNeeded()
            }
        }
    }

    public func initialPaywallDismissed() {
        guard
            route == .initialPaywall,
            configuration.allowsInitialPaywallClose,
            !isTransitionInFlight
        else {
            return
        }

        guard configuration.persistsInitialPaywallResolution else {
            route = stateMachine.initialPaywallDismissed()
            return
        }

        let generation = beginTransition()
        let repository = progressRepository

        transitionTask = Task { @MainActor [weak self, repository] in
            let checkpoint = await repository.advance(to: .initialPaywallResolved)
            guard let self, isCurrent(generation) else {
                return
            }

            if checkpoint.hasResolvedInitialPaywall {
                route = stateMachine.initialPaywallDismissed()
            }

            completeTransition(generation)
        }
    }

    public func initialPaywallUnavailable() {
        guard route == .initialPaywall else {
            return
        }

        cancelTransition()
        route = stateMachine.initialPaywallUnavailable()
    }

    public func restart() {
        cancelTransition()
        didStart = false
        hasConfirmedActiveEntitlement = false
        route = stateMachine.restart()
    }

    private func resolve(
        checkpoint: AppFlowCheckpoint,
        provider: any EntitlementStatusProviderProtocol,
        generation: UInt64
    ) async {
        transitionCheckpoint = checkpoint
        let progressRoute = stateMachine.resolve(
            checkpoint: checkpoint,
            entitlementStatus: nil
        )

        guard isCurrent(generation) else {
            return
        }

        guard progressRoute == .launch else {
            route = progressRoute
            completeTransition(generation)
            return
        }

        let resolvedStatus: EntitlementStatus
        if hasConfirmedActiveEntitlement {
            resolvedStatus = .active
        } else {
            resolvedStatus = await provider.currentStatus()
            guard isCurrent(generation) else {
                return
            }
        }

        let effectiveStatus: EntitlementStatus = hasConfirmedActiveEntitlement
            ? .active
            : resolvedStatus
        await apply(
            status: effectiveStatus,
            checkpoint: checkpoint,
            generation: generation
        )
    }

    private func apply(
        status: EntitlementStatus,
        checkpoint: AppFlowCheckpoint,
        generation: UInt64
    ) async {
        if status == .active {
            hasConfirmedActiveEntitlement = true
        }

        let resolvedRoute = stateMachine.resolve(
            checkpoint: checkpoint,
            entitlementStatus: status
        )

        route = resolvedRoute

        if status == .active,
           resolvedRoute == .main,
           configuration.persistsInitialPaywallResolution {
            _ = await progressRepository.advance(to: .initialPaywallResolved)
            guard isCurrent(generation) else {
                return
            }
        }

        completeTransition(generation)
    }

    private func resolveInFlightTransitionWithConfirmedActiveEntitlement() {
        guard isTransitionInFlight, let checkpoint = transitionCheckpoint else {
            return
        }

        cancelTransition()
        let resolvedRoute = stateMachine.resolve(
            checkpoint: checkpoint,
            entitlementStatus: .active
        )
        route = resolvedRoute

        if resolvedRoute == .main {
            persistResolvedPaywallIfNeeded()
        }
    }

    private func persistResolvedPaywallIfNeeded() {
        guard configuration.persistsInitialPaywallResolution else {
            return
        }

        let generation = beginTransition()
        let repository = progressRepository

        transitionTask = Task { @MainActor [weak self, repository] in
            _ = await repository.advance(to: .initialPaywallResolved)
            guard let self, isCurrent(generation) else {
                return
            }

            completeTransition(generation)
        }
    }

    private func beginTransition() -> UInt64 {
        transitionTask?.cancel()
        transitionGeneration &+= 1
        transitionCheckpoint = nil
        isTransitionInFlight = true
        return transitionGeneration
    }

    private func cancelTransition() {
        transitionTask?.cancel()
        transitionTask = nil
        transitionGeneration &+= 1
        transitionCheckpoint = nil
        isTransitionInFlight = false
    }

    private func isCurrent(_ generation: UInt64) -> Bool {
        transitionGeneration == generation && !Task.isCancelled
    }

    private func completeTransition(_ generation: UInt64) {
        guard transitionGeneration == generation else {
            return
        }

        isTransitionInFlight = false
        transitionCheckpoint = nil
        transitionTask = nil
    }
}
