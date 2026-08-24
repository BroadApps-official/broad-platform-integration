import BroadMonetization
import Foundation

extension PaywallViewModel {
    @discardableResult
    public func requestClose(reason: PaywallCloseReason = .dismissed) -> Bool {
        guard isCloseAvailable, !isPurchaseInFlight, !isRestoreInFlight else {
            return false
        }

        trackClose(reason: reason)
        cancelDismissedOperations()
        return true
    }

    public func consumeCompletionEvent(id: UUID) {
        guard completionEvent?.id == id else {
            return
        }

        completionEvent = nil
    }

    func trackShown(_ payload: PaywallPayload) {
        guard lastShownPresentationID != payload.presentationID else {
            return
        }

        lastShownPresentationID = payload.presentationID
        track(.paywallShown(PaywallAnalyticsContext(paywall: payload)))
    }

    func trackClose(reason: PaywallCloseReason) {
        guard
            let payload = state.payload,
            lastClosedPresentationID != payload.presentationID
        else {
            return
        }

        lastClosedPresentationID = payload.presentationID
        track(
            .paywallClosed(
                PaywallAnalyticsContext(paywall: payload),
                reason: reason
            )
        )
    }

    func track(_ event: MonetizationAnalyticsEvent) {
        let useCase = dependencies.trackEvent
        let previous = eventTask
        eventTask = Task { [previous, useCase] in
            await previous?.value
            await useCase(event)
        }
    }

    func cancelDismissedOperations() {
        loadGeneration &+= 1
        loadTask?.cancel()
        checkoutTask?.cancel()
        closeAvailabilityTask?.cancel()

        loadTask = nil
        checkoutTask = nil
        closeAvailabilityTask = nil
        checkoutMethods = []
        isResolvingCheckoutMethods = false
    }
}
