import BroadMonetization
import Foundation

extension PaywallViewModel {
    public func loadIfNeeded() {
        guard case .idle = state else {
            return
        }

        if let preparedInitialPayload {
            self.preparedInitialPayload = nil
            apply(.loaded(preparedInitialPayload))
            return
        }

        load(preservingCloseAvailability: false)
    }

    public func retry() {
        guard loadTask == nil, !isBusy else {
            return
        }

        let mustRemainClosable = switch state {
        case .empty, .failure:
            true
        case .idle, .loading, .content:
            false
        }

        load(preservingCloseAvailability: mustRemainClosable)
    }

    public func selectProduct(presentationID: ProductPresentationID) {
        guard
            canSelectProducts,
            case let .content(payload) = state,
            selectedProductPresentationID != presentationID,
            let product = payload.products.first(where: {
                $0.presentationID == presentationID
            }),
            product.isEligibleForGenericPurchase,
            let selection = dependencies.selectProduct(
                productPresentationID: presentationID,
                in: payload
            )
        else {
            return
        }

        selectedSelection = selection
        selectedProductPresentationID = presentationID
        inlineFeedback = nil

        track(
            .productSelected(
                PaywallAnalyticsContext(paywall: payload),
                product: ProductAnalyticsContext(product: product)
            )
        )
    }

    func load(preservingCloseAvailability: Bool) {
        loadGeneration &+= 1
        let generation = loadGeneration

        checkoutMethods = []
        selectedSelection = nil
        selectedProductPresentationID = nil
        inlineFeedback = nil
        state = .loading

        closeAvailabilityTask?.cancel()
        closeAvailabilityTask = nil
        if !preservingCloseAvailability {
            isCloseAvailable = configuration.access.defaultPolicy == .soft
        }

        let request = configuration.request
        let useCase = dependencies.loadPaywall
        let presentationLifecycle = dependencies.presentationLifecycle

        loadTask = Task { @MainActor [weak self, presentationLifecycle, useCase] in
            let outcome = await useCase(request)

            guard
                let self,
                !Task.isCancelled,
                loadGeneration == generation
            else {
                if case let .loaded(payload) = outcome {
                    await presentationLifecycle.presentationDidEnd(
                        PaywallAnalyticsContext(paywall: payload)
                    )
                }
                return
            }

            loadTask = nil
            apply(outcome)
        }
    }

    func apply(_ outcome: PaywallLoadOutcome) {
        switch outcome {
        case let .loaded(payload):
            trackShown(payload)

            guard !payload.products.isEmpty else {
                state = .empty(payload)
                isCloseAvailable = true
                return
            }

            state = .content(payload)
            selectInitialProduct(in: payload)
            configureCloseAvailability(for: payload)
        case let .unavailable(error):
            state = .failure(error)
            isCloseAvailable = true
        }
    }

    func selectInitialProduct(in payload: PaywallPayload) {
        let configuredID = configuration.defaultSelection?.resolve(in: payload.products)
        let configuredProduct = configuredID.flatMap { presentationID in
            payload.products.first(where: {
                $0.presentationID == presentationID
                    && $0.isEligibleForGenericPurchase
            })
        }
        guard
            let product = configuredProduct
            ?? payload.products.first(where: \.isEligibleForGenericPurchase),
            let selection = dependencies.selectProduct(
                productPresentationID: product.presentationID,
                in: payload
            )
        else {
            return
        }

        selectedSelection = selection
        selectedProductPresentationID = product.presentationID
    }

    func configureCloseAvailability(for payload: PaywallPayload) {
        // A hard paywall without a safely purchasable occurrence must never
        // trap the user behind disabled rows. Keep the 1:1 catalog visible,
        // but make close immediately available.
        guard payload.products.contains(where: \.isEligibleForGenericPurchase) else {
            isCloseAvailable = true
            return
        }

        let policy = payload.remoteConfiguration.accessPolicy ?? configuration.access.defaultPolicy
        guard policy == .hard else {
            isCloseAvailable = true
            return
        }

        let configuredDelay = payload.remoteConfiguration.closeDelay
            ?? configuration.access.hardPaywallCloseDelay
        let delay = BroadPaywallAccessConfiguration.normalized(delay: configuredDelay)

        guard delay > 0 else {
            isCloseAvailable = true
            return
        }

        isCloseAvailable = false
        let presentationID = payload.presentationID
        closeAvailabilityTask = Task { @MainActor [weak self] in
            do {
                try await ContinuousClock().sleep(for: .seconds(delay))
            } catch {
                return
            }

            guard
                let self,
                !Task.isCancelled,
                state.payload?.presentationID == presentationID
            else {
                return
            }

            closeAvailabilityTask = nil
            isCloseAvailable = true
        }
    }
}
