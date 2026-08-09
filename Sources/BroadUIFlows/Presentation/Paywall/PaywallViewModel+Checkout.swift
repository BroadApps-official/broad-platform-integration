import BroadCore
import BroadMonetization

extension PaywallViewModel {
    public func purchaseButtonTapped() {
        guard
            canPurchase,
            checkoutMethods.isEmpty,
            let selection = selectedSelection,
            case let .content(payload) = state
        else {
            return
        }

        isResolvingCheckoutMethods = true
        inlineFeedback = nil

        let useCase = dependencies.resolveCheckoutMethods
        checkoutTask = Task { @MainActor [weak self, useCase] in
            let resolution = await useCase(
                for: selection.product,
                remoteConfiguration: payload.remoteConfiguration
            )

            guard let self, !Task.isCancelled else {
                return
            }

            checkoutTask = nil
            isResolvingCheckoutMethods = false
            applyCheckoutMethods(
                resolution.methods,
                selection: selection,
                remoteConfiguration: payload.remoteConfiguration
            )
        }
    }

    public func chooseCheckoutMethod(_ method: CheckoutMethod) {
        guard
            !isBusy,
            !isFinancialOperationPending,
            checkoutMethods.contains(method),
            let selection = selectedSelection,
            selection.product.isEligibleForGenericPurchase,
            case let .content(payload) = state
        else {
            return
        }

        checkoutMethods = []
        beginCheckout(
            selection: selection,
            method: method,
            remoteConfiguration: payload.remoteConfiguration
        )
    }

    public func cancelCheckoutMethodSelection() {
        guard !isPurchaseInFlight else {
            return
        }

        checkoutMethods = []
    }

    public func restorePurchases() {
        guard !isBusy, !isFinancialOperationPending else {
            return
        }

        isRestoreInFlight = true
        inlineFeedback = nil

        let useCase = dependencies.restorePurchases
        restoreTask = Task { @MainActor [weak self, useCase] in
            let outcome = await useCase()

            guard let self, !Task.isCancelled else {
                return
            }

            restoreTask = nil
            isRestoreInFlight = false
            applyRestoreOutcome(outcome)
        }
    }

    func applyCheckoutMethods(
        _ methods: [CheckoutMethod],
        selection: ProductSelection,
        remoteConfiguration: RemotePaywallConfiguration
    ) {
        guard !isFinancialOperationPending else {
            checkoutMethods = []
            return
        }

        switch methods.count {
        case 0:
            inlineFeedback = .failure(checkoutUnavailableError)
        case 1:
            if let method = methods.first {
                beginCheckout(
                    selection: selection,
                    method: method,
                    remoteConfiguration: remoteConfiguration
                )
            }
        default:
            checkoutMethods = methods
        }
    }

    func beginCheckout(
        selection: ProductSelection,
        method: CheckoutMethod,
        remoteConfiguration: RemotePaywallConfiguration
    ) {
        guard purchaseTask == nil,
              !isRestoreInFlight,
              !isFinancialOperationPending,
              selection.product.isEligibleForGenericPurchase
        else {
            return
        }

        isPurchaseInFlight = true
        inlineFeedback = nil

        let useCase = dependencies.checkoutProduct
        purchaseTask = Task { @MainActor [weak self, useCase] in
            let outcome = await useCase(
                selection,
                using: method,
                remoteConfiguration: remoteConfiguration
            )

            guard let self, !Task.isCancelled else {
                return
            }

            purchaseTask = nil
            isPurchaseInFlight = false
            applyCheckoutOutcome(outcome)
        }
    }

    func applyCheckoutOutcome(_ outcome: CheckoutSelectedProductOutcome) {
        switch outcome {
        case let .activated(snapshot):
            inlineFeedback = nil
            trackClose(reason: .purchased)
            completionEvent = BroadPaywallCompletionEvent(
                completion: .purchased(snapshot)
            )
        case .completed:
            refreshFinancialOperationStatus()
            inlineFeedback = .notice(
                configuration.copy.states.purchase.completedMessage
            )
        case .completedButUnverified:
            refreshFinancialOperationStatus()
            inlineFeedback = .notice(
                configuration.copy.states.purchase.completedButUnverifiedMessage
            )
        case .cancelled:
            refreshFinancialOperationStatus()
            inlineFeedback = nil
        case .pending:
            isFinancialOperationPending = true
            inlineFeedback = .notice(configuration.copy.states.purchase.pendingMessage)
        case let .failed(error):
            refreshFinancialOperationStatus()
            inlineFeedback = .failure(error)
        }
    }

    func applyRestoreOutcome(_ outcome: RestoreOutcome) {
        switch outcome {
        case let .restored(snapshot):
            inlineFeedback = nil
            trackClose(reason: .purchased)
            completionEvent = BroadPaywallCompletionEvent(
                completion: .restored(snapshot)
            )
        case .nothingFound:
            refreshFinancialOperationStatus()
            inlineFeedback = .notice(configuration.copy.states.nothingToRestoreMessage)
        case let .unavailable(error), let .failed(error):
            refreshFinancialOperationStatus()
            inlineFeedback = .failure(error)
        }
    }

    var checkoutUnavailableError: AppError {
        AppError(
            kind: .unavailable,
            userMessage: configuration.copy.states.checkoutUnavailableMessage,
            diagnosticCode: "paywall.checkout-methods.empty",
            isRetryable: true
        )
    }
}
