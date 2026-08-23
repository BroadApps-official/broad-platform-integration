import BroadCore
import BroadMonetization
import Foundation

public struct BroadTokenPaywallViewModelDependencies: Sendable {
    let loadPaywall: any LoadPaywallUseCaseProtocol
    let selectProduct: any SelectProductUseCaseProtocol
    let purchaseManager: TokenPurchaseManager
    let recoverTokenAccount: any RecoverTokenAccountUseCaseProtocol
    let onBalanceConfirmed: @MainActor @Sendable (TokenBalanceSnapshot) -> Void

    public init(
        loadPaywall: any LoadPaywallUseCaseProtocol,
        selectProduct: any SelectProductUseCaseProtocol,
        purchaseManager: TokenPurchaseManager,
        recoverTokenAccount: any RecoverTokenAccountUseCaseProtocol,
        onBalanceConfirmed: @escaping @MainActor @Sendable (
            TokenBalanceSnapshot
        ) -> Void
    ) {
        self.loadPaywall = loadPaywall
        self.selectProduct = selectProduct
        self.purchaseManager = purchaseManager
        self.recoverTokenAccount = recoverTokenAccount
        self.onBalanceConfirmed = onBalanceConfirmed
    }
}

@MainActor
public final class BroadTokenPaywallViewModel: ObservableObject {
    @Published public private(set) var state: BroadTokenPaywallViewState = .idle
    @Published public private(set) var selectedProductPresentationID:
        ProductPresentationID?
    @Published public private(set) var balanceSnapshot: TokenBalanceSnapshot?
    @Published public private(set) var feedback: BroadTokenPaywallFeedback?
    @Published public private(set) var analyticsRecords: [
        BroadTokenPaywallAnalyticsRecord
    ] = []
    @Published public private(set) var isPurchaseInFlight = false
    @Published public private(set) var isRecoveringPendingPurchase = false
    @Published public private(set) var isRecoveringAccountBalance = false
    @Published public private(set) var isRetrySuggested = false

    public let configuration: BroadTokenPaywallConfiguration

    private let dependencies: BroadTokenPaywallViewModelDependencies
    private var selectedSelection: ProductSelection?
    private var loadTask: Task<Void, Never>?
    private var purchaseTask: Task<Void, Never>?
    private var pendingRecoveryTask: Task<Void, Never>?
    private var accountRecoveryTask: Task<Void, Never>?
    private var hasRecoveredAccountBalance = false

    public init(
        configuration: BroadTokenPaywallConfiguration,
        dependencies: BroadTokenPaywallViewModelDependencies
    ) {
        self.configuration = configuration
        self.dependencies = dependencies
    }

    deinit {
        loadTask?.cancel()
        purchaseTask?.cancel()
        pendingRecoveryTask?.cancel()
        accountRecoveryTask?.cancel()
    }

    public var selectedProduct: MonetizationProduct? {
        selectedSelection?.product
    }

    public var isBusy: Bool {
        isPurchaseInFlight
            || isRecoveringPendingPurchase
            || isRecoveringAccountBalance
    }

    public var canPurchase: Bool {
        guard case .content = state,
              selectedSelection?.product.isEligibleForTokenPurchase == true
        else {
            return false
        }
        return !isBusy
    }

    public var canSelectProducts: Bool {
        !isBusy
    }

    public func viewDidAppear() {
        loadIfNeeded()
        recoverAccountBalanceIfNeeded()
        recoverPendingPurchaseIfNeeded()
    }

    public func loadIfNeeded() {
        guard loadTask == nil else {
            return
        }
        guard case .idle = state else {
            return
        }

        state = .loading
        record(.loadStarted)
        let request = configuration.request
        let loadPaywall = dependencies.loadPaywall
        loadTask = Task { @MainActor [weak self, loadPaywall] in
            let outcome = await loadPaywall(request)
            guard let self, !Task.isCancelled else {
                return
            }
            loadTask = nil
            applyLoadOutcome(outcome)
        }
    }

    public func retryLoad() {
        guard !isBusy else {
            return
        }
        state = .idle
        selectedSelection = nil
        selectedProductPresentationID = nil
        loadIfNeeded()
    }

    public func selectProduct(
        presentationID: ProductPresentationID
    ) {
        guard canSelectProducts, let paywall = state.payload,
              let selection = dependencies.selectProduct(
                  productPresentationID: presentationID,
                  in: paywall
              ),
              selection.product.isEligibleForTokenPurchase
        else {
            return
        }

        selectedSelection = selection
        selectedProductPresentationID = presentationID
        record(.productSelected)
    }

    public func purchaseSelectedProduct() {
        guard canPurchase, let selection = selectedSelection,
              purchaseTask == nil
        else {
            return
        }

        isPurchaseInFlight = true
        feedback = nil
        isRetrySuggested = false
        record(.purchaseStarted)
        let manager = dependencies.purchaseManager
        purchaseTask = Task { @MainActor [weak self, manager] in
            let outcome = await manager.purchase(selection)
            guard let self, !Task.isCancelled else {
                return
            }
            purchaseTask = nil
            isPurchaseInFlight = false
            applyPurchaseOutcome(outcome)
        }
    }

    public func retrySafely() {
        guard !isBusy, isRetrySuggested,
              pendingRecoveryTask == nil
        else {
            return
        }

        isRecoveringPendingPurchase = true
        feedback = nil
        record(.reconciliationStarted)
        let manager = dependencies.purchaseManager
        pendingRecoveryTask = Task { @MainActor [weak self, manager] in
            let recovered = await manager.recoverPendingPurchase()
            guard let self, !Task.isCancelled else {
                return
            }
            pendingRecoveryTask = nil
            isRecoveringPendingPurchase = false
            if let recovered {
                applyPurchaseOutcome(recovered)
            } else {
                purchaseSelectedProduct()
            }
        }
    }

    public func recoverPendingPurchaseIfNeeded() {
        guard pendingRecoveryTask == nil, purchaseTask == nil else {
            return
        }

        isRecoveringPendingPurchase = true
        let manager = dependencies.purchaseManager
        pendingRecoveryTask = Task { @MainActor [weak self, manager] in
            let outcome = await manager.recoverPendingPurchase()
            guard let self, !Task.isCancelled else {
                return
            }
            pendingRecoveryTask = nil
            isRecoveringPendingPurchase = false
            if let outcome {
                record(.reconciliationStarted)
                applyPurchaseOutcome(outcome)
            }
        }
    }

    public func recoverAccountBalance() {
        hasRecoveredAccountBalance = false
        recoverAccountBalanceIfNeeded()
    }

    public func recoverAccountBalanceIfNeeded() {
        guard !hasRecoveredAccountBalance, accountRecoveryTask == nil else {
            return
        }

        isRecoveringAccountBalance = true
        let recoverTokenAccount = dependencies.recoverTokenAccount
        accountRecoveryTask = Task { @MainActor [weak self, recoverTokenAccount] in
            let outcome = await recoverTokenAccount()
            guard let self, !Task.isCancelled else {
                return
            }
            accountRecoveryTask = nil
            isRecoveringAccountBalance = false
            hasRecoveredAccountBalance = true
            switch outcome {
            case let .restored(snapshot):
                applyConfirmedBalance(snapshot)
                feedback = .recovered(snapshot)
                record(.balanceRecovered)
            case let .unavailable(error):
                feedback = .failed(error)
            }
        }
    }
}

private extension BroadTokenPaywallViewModel {
    static let unexpectedPlacementError = AppError(
        kind: .unavailable,
        userMessage: "Token placement вернул неподходящий или subscription-каталог.",
        diagnosticCode: "ui-flows.token-paywall.unexpected-placement",
        isRetryable: true
    )

    func applyLoadOutcome(_ outcome: PaywallLoadOutcome) {
        switch outcome {
        case let .loaded(paywall):
            guard paywall.origin.requestedPlacementID == .tokens,
                  isSafeTokenPlacement(paywall)
            else {
                state = .failure(Self.unexpectedPlacementError)
                record(.loadFailed)
                return
            }
            guard !paywall.products.isEmpty else {
                state = .empty(paywall)
                record(.loadSucceeded)
                return
            }

            state = .content(paywall)
            record(.loadSucceeded)
            selectDefaultProduct(in: paywall)
        case let .unavailable(error):
            state = .failure(error)
            record(.loadFailed)
        }
    }

    func selectDefaultProduct(in paywall: PaywallPayload) {
        let products = paywall.products
        let preferredIndex = configuration.defaultSelectionIndex
        let product: MonetizationProduct? = if products.indices.contains(preferredIndex),
                                               products[preferredIndex].isEligibleForTokenPurchase {
            products[preferredIndex]
        } else {
            products.first(where: \.isEligibleForTokenPurchase)
        }
        guard let product,
              let selection = dependencies.selectProduct(
                  productPresentationID: product.presentationID,
                  in: paywall
              )
        else {
            return
        }

        selectedSelection = selection
        selectedProductPresentationID = product.presentationID
    }

    func applyPurchaseOutcome(_ outcome: TokenPurchaseOutcome) {
        switch outcome {
        case let .credited(snapshot):
            applyConfirmedBalance(snapshot)
            feedback = .credited(snapshot)
            isRetrySuggested = false
            record(.purchaseCredited)
        case .pending:
            feedback = .pending
            isRetrySuggested = true
            record(.purchasePending)
        case .cancelled:
            feedback = .cancelled
            isRetrySuggested = false
            record(.purchaseCancelled)
        case let .failed(error):
            feedback = .failed(error)
            isRetrySuggested = error.isRetryable
            record(.purchaseFailed)
        }
    }

    func applyConfirmedBalance(_ snapshot: TokenBalanceSnapshot) {
        balanceSnapshot = snapshot
        dependencies.onBalanceConfirmed(snapshot)
    }

    func record(_ event: BroadTokenPaywallAnalyticsEvent) {
        analyticsRecords.append(BroadTokenPaywallAnalyticsRecord(event: event))
        if analyticsRecords.count > 40 {
            analyticsRecords.removeFirst(analyticsRecords.count - 40)
        }
    }

    func isSafeTokenPlacement(_ paywall: PaywallPayload) -> Bool {
        if paywall.origin.resolvedPlacementID == .tokens {
            return true
        }

        return paywall.origin.resolvedPlacementID == .main
            && paywall.origin.usedFallback
            && paywall.products.allSatisfy { $0.kind == .consumable }
    }
}

private extension MonetizationProduct {
    var isEligibleForTokenPurchase: Bool {
        kind == .consumable && price != nil
    }
}
