import BroadCore
import Combine
import Foundation

@MainActor
public final class OnboardingViewModel: ObservableObject {
    @Published public private(set) var currentIndex = 0
    @Published public private(set) var trackingAuthorizationStatus: TrackingAuthorizationStatus?

    public let configuration: OnboardingConfiguration

    private let requestTrackingAuthorizationUseCase: any TrackingAuthorizationUseCaseProtocol

    private var authorizationTask: Task<Void, Never>?
    private var authorizationTaskGeneration: UInt64 = 0
    private var hasRequestedTrackingAuthorization = false
    private var isOnboardingVisible = false
    private var isFirstSlideVisible = false
    private var isApplicationActive = false
    private var isWindowVisible = false
    private var validateCurrentWindowVisibility: (@MainActor () -> Bool)?
    private var hasCompletedInvalidConfiguration = false

    public init(
        configuration: OnboardingConfiguration,
        requestTrackingAuthorizationUseCase: any TrackingAuthorizationUseCaseProtocol
    ) {
        self.configuration = configuration
        self.requestTrackingAuthorizationUseCase = requestTrackingAuthorizationUseCase
    }

    deinit {
        authorizationTask?.cancel()
    }

    public var currentPage: OnboardingPageConfiguration? {
        guard configuration.isValid, configuration.pages.indices.contains(currentIndex) else {
            return nil
        }
        return configuration.pages[currentIndex]
    }

    public var isLastPage: Bool {
        !configuration.isValid || currentIndex == configuration.pages.count - 1
    }

    public func onboardingDidAppear() {
        isOnboardingVisible = true
        scheduleTrackingAuthorizationIfEligible()
    }

    public func onboardingDidDisappear() {
        isOnboardingVisible = false
        isFirstSlideVisible = false
        isWindowVisible = false
        validateCurrentWindowVisibility = nil
        cancelPendingTrackingAuthorization()
    }

    /// Returns true once for an invalid app/remote configuration so the host can
    /// move to its next safe route without rendering or requesting ATT.
    public func completeInvalidConfigurationIfNeeded() -> Bool {
        guard !configuration.isValid, !hasCompletedInvalidConfiguration else {
            return false
        }

        hasCompletedInvalidConfiguration = true
        return true
    }

    public func firstSlideDidAppear() {
        guard currentPage != nil, currentIndex == configuration.pages.startIndex else {
            return
        }

        isFirstSlideVisible = true
        scheduleTrackingAuthorizationIfEligible()
    }

    public func firstSlideDidDisappear() {
        isFirstSlideVisible = false
        cancelPendingTrackingAuthorization()
    }

    public func applicationActiveDidChange(_ isActive: Bool) {
        isApplicationActive = isActive
        updateTrackingAuthorizationTask(for: isActive)
    }

    /// Source-compatible lifecycle hook for custom renderers that own their
    /// visibility signal. `BroadOnboardingView` uses the live-validator overload.
    public func windowVisibilityDidChange(_ isVisible: Bool) {
        windowVisibilityDidChange(
            isVisible,
            validateCurrentVisibility: { isVisible }
        )
    }

    func windowVisibilityDidChange(
        _ isVisible: Bool,
        validateCurrentVisibility: (@MainActor () -> Bool)?
    ) {
        isWindowVisible = isVisible
        validateCurrentWindowVisibility = validateCurrentVisibility
        updateTrackingAuthorizationTask(for: isVisible)
    }

    @discardableResult
    public func advance() -> Bool {
        guard configuration.isValid, !isLastPage else {
            return true
        }

        currentIndex += 1
        isFirstSlideVisible = false
        cancelPendingTrackingAuthorization()
        return false
    }

    private func updateTrackingAuthorizationTask(for conditionIsSatisfied: Bool) {
        if conditionIsSatisfied {
            scheduleTrackingAuthorizationIfEligible()
        } else {
            cancelPendingTrackingAuthorization()
        }
    }

    private func scheduleTrackingAuthorizationIfEligible() {
        guard
            authorizationTask == nil,
            !hasRequestedTrackingAuthorization,
            let delay = configuration.trackingAuthorizationPolicy.requestDelay,
            isEligibleForTrackingAuthorization
        else {
            return
        }

        authorizationTaskGeneration &+= 1
        let generation = authorizationTaskGeneration
        let useCase = requestTrackingAuthorizationUseCase

        authorizationTask = Task { @MainActor [weak self, useCase] in
            do {
                try await ContinuousClock().sleep(for: delay)
            } catch {
                self?.clearAuthorizationTask(generation: generation)
                return
            }

            guard
                let self,
                !Task.isCancelled,
                authorizationTaskGeneration == generation,
                isEligibleForTrackingAuthorization
            else {
                self?.clearAuthorizationTask(generation: generation)
                return
            }

            hasRequestedTrackingAuthorization = true
            let status = await useCase()

            guard !Task.isCancelled, authorizationTaskGeneration == generation else {
                clearAuthorizationTask(generation: generation)
                return
            }

            trackingAuthorizationStatus = status
            clearAuthorizationTask(generation: generation)
        }
    }

    private var isEligibleForTrackingAuthorization: Bool {
        configuration.isValid &&
            isOnboardingVisible &&
            isFirstSlideVisible &&
            currentIndex == configuration.pages.startIndex &&
            isApplicationActive &&
            isWindowVisible &&
            validateCurrentWindowVisibility?() == true
    }

    private func cancelPendingTrackingAuthorization() {
        authorizationTaskGeneration &+= 1
        authorizationTask?.cancel()
        authorizationTask = nil
    }

    private func clearAuthorizationTask(generation: UInt64) {
        guard authorizationTaskGeneration == generation else {
            return
        }

        authorizationTask = nil
    }
}
