import BroadCore
import BroadMonetization
import Foundation

struct ExampleTokenPaywallRepository: PaywallRepositoryProtocol {
    let arguments: [String]

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        self.arguments = arguments
    }

    func loadPaywall(
        for placementID: PlacementID
    ) async -> PaywallLoadOutcome {
        let usesMainFallback = arguments.contains(
            "-token-paywall-main-fallback"
        )
        if usesMainFallback, placementID == .tokens {
            return .unavailable(
                .example(
                    message: "Token placement недоступен; проверяем безопасный резерв main.",
                    code: "example.tokens.main-fallback-requested"
                )
            )
        }

        guard placementID == .tokens
            || usesMainFallback && placementID == .main
        else {
            return .unavailable(
                .example(
                    message: "Fixture token repository обслуживает только .tokens и проверяемый резерв .main.",
                    code: "example.tokens.wrong-placement"
                )
            )
        }

        try? await Task.sleep(nanoseconds: 350_000_000)
        return .loaded(
            PaywallPayload(
                presentationID: .generated(),
                paywallReference: PaywallReference(
                    rawValue: "example-token-paywall-\(placementID.rawValue)"
                ),
                variationID: PaywallVariationID(
                    rawValue: "example-token-fixture"
                ),
                origin: PaywallOrigin(
                    requestedPlacementID: placementID,
                    resolvedPlacementID: placementID,
                    catalogSource: .adapty
                ),
                products: ExampleTokenPackage.all.enumerated().map { index, package in
                    package.makeProduct(index: index)
                },
                fetchedAt: Date()
            )
        )
    }
}

actor ExampleTokenTransactionLedger {
    private var evidenceByProductID: [
        ProductID: [TokenTransactionEvidence]
    ] = [:]

    func recordPurchase(
        productID: ProductID
    ) -> TokenTransactionEvidence {
        let evidence = TokenTransactionEvidence(
            transactionID: "fixture-token-\(UUID().uuidString)",
            productID: productID,
            signedTransaction: "fixture-signed-evidence-not-for-production",
            purchasedAt: Date()
        )
        evidenceByProductID[productID, default: []].append(evidence)
        return evidence
    }

    func evidence(
        productID: ProductID,
        purchasedAfter: Date
    ) -> TokenEvidenceResolution {
        guard let evidence = evidenceByProductID[productID]?
            .last(where: { $0.purchasedAt >= purchasedAfter })
        else {
            return .notFound
        }
        return .verified(evidence)
    }
}

struct ExampleTokenTransactionEvidenceProvider:
    TokenTransactionEvidenceProviderProtocol {
    let ledger: ExampleTokenTransactionLedger

    func evidence(
        productID: ProductID,
        purchasedAfter: Date
    ) async -> TokenEvidenceResolution {
        await ledger.evidence(
            productID: productID,
            purchasedAfter: purchasedAfter
        )
    }
}

struct ExampleTokenPurchaseRepository: PurchaseRepositoryProtocol {
    let ledger: ExampleTokenTransactionLedger

    func purchase(
        _ request: PurchaseRequest
    ) async -> PurchaseAttemptOutcome {
        guard request.checkoutMethod == .apple,
              request.selection.product.kind == .consumable
        else {
            return .failed(
                .example(
                    message: "Token fixture принимает только consumable Apple selection.",
                    code: "example.tokens.unsupported-selection"
                ),
                disposition: .definitivelyNotPurchased
            )
        }

        try? await Task.sleep(nanoseconds: 650_000_000)
        switch ExampleTokenPackage(
            productID: request.selection.product.productID
        )?.scenario {
        case .cancelled:
            return .cancelled
        case .providerFailure:
            return .failed(
                .example(
                    message: "Fixture-provider отклонил операцию до списания.",
                    code: "example.tokens.provider-failure"
                ),
                disposition: .definitivelyNotPurchased
            )
        case .credited, .pending, .backendFailure, .offline:
            _ = await ledger.recordPurchase(
                productID: request.selection.product.productID
            )
            return .completed(
                PurchaseConfirmation(
                    productID: request.selection.product.productID,
                    checkoutMethod: .apple,
                    confirmedAt: Date()
                )
            )
        case nil:
            return .failed(
                .example(
                    message: "Неизвестный fixture-пакет токенов.",
                    code: "example.tokens.unknown-package"
                ),
                disposition: .definitivelyNotPurchased
            )
        }
    }
}

actor ExampleTokenFulfillmentRepository:
    TokenFulfillmentRepositoryProtocol,
    RecoverTokenAccountUseCaseProtocol {
    private var balance: Decimal = 120
    private var snapshotsByTransactionID: [String: TokenBalanceSnapshot] = [:]
    private var attemptsByTransactionID: [String: Int] = [:]

    func fulfill(
        _ request: TokenFulfillmentRequest
    ) async -> TokenFulfillmentOutcome {
        try? await Task.sleep(nanoseconds: 650_000_000)

        let transactionID = request.evidence.transactionID
        if let snapshot = snapshotsByTransactionID[transactionID] {
            return .alreadyCredited(snapshot)
        }

        let attempt = (attemptsByTransactionID[transactionID] ?? 0) + 1
        attemptsByTransactionID[transactionID] = attempt
        guard let package = ExampleTokenPackage(
            productID: request.evidence.productID
        ) else {
            return .failed(
                .example(
                    message: "Backend не распознал пакет токенов.",
                    code: "example.tokens.backend-unknown-package"
                )
            )
        }

        switch package.scenario {
        case .pending where attempt == 1:
            return .pending
        case .backendFailure where attempt == 1:
            return .failed(
                .example(
                    message: "Backend временно не подтвердил начисление. Повтор не спишет деньги ещё раз.",
                    code: "example.tokens.backend-failure"
                )
            )
        case .offline where attempt == 1:
            return .unavailable(
                .example(
                    message: "Сеть недоступна. Сохранённое доказательство можно сверить повторно.",
                    code: "example.tokens.offline"
                )
            )
        case .credited, .pending, .backendFailure, .offline:
            balance += package.tokenAmount
            let snapshot = TokenBalanceSnapshot(
                balance: balance,
                updatedAt: Date()
            )
            snapshotsByTransactionID[transactionID] = snapshot
            return .credited(snapshot)
        case .cancelled, .providerFailure:
            return .failed(
                .example(
                    message: "Backend не получил подтверждённую token transaction.",
                    code: "example.tokens.missing-transaction"
                )
            )
        }
    }

    func callAsFunction() async -> TokenAccountRecoveryOutcome {
        try? await Task.sleep(nanoseconds: 450_000_000)
        return .restored(
            TokenBalanceSnapshot(balance: balance, updatedAt: Date())
        )
    }
}

private struct ExampleTokenPackage {
    enum Scenario {
        case credited
        case pending
        case cancelled
        case providerFailure
        case backendFailure
        case offline
    }

    let productID: ProductID
    let tokenAmount: Decimal
    let title: String
    let subtitle: String
    let price: Decimal
    let displayPrice: String
    let scenario: Scenario

    init(
        productID: ProductID,
        tokenAmount: Decimal,
        title: String,
        subtitle: String,
        price: Decimal,
        displayPrice: String,
        scenario: Scenario
    ) {
        self.productID = productID
        self.tokenAmount = tokenAmount
        self.title = title
        self.subtitle = subtitle
        self.price = price
        self.displayPrice = displayPrice
        self.scenario = scenario
    }

    init?(
        productID: ProductID
    ) {
        guard let package = Self.all.first(where: {
            $0.productID == productID
        }) else {
            return nil
        }
        self = package
    }

    func makeProduct(index: Int) -> MonetizationProduct {
        MonetizationProduct(
            presentationID: .generated(),
            reference: ProductReference(
                rawValue: "example-token-reference-\(index)-\(UUID().uuidString)"
            ),
            productID: productID,
            kind: .consumable,
            title: title,
            subtitle: subtitle,
            price: Money(amount: price, currencyCode: "USD"),
            displayPrice: displayPrice,
            catalogSource: .adapty
        )
    }

    static let all = [
        ExampleTokenPackage(
            productID: ProductID(rawValue: "example.tokens.100"),
            tokenAmount: 100,
            title: "100 токенов",
            subtitle: "Backend начисляет сразу",
            price: 0.99,
            displayPrice: "$0.99",
            scenario: .credited
        ),
        ExampleTokenPackage(
            productID: ProductID(rawValue: "example.tokens.500.pending"),
            tokenAmount: 500,
            title: "500 токенов",
            subtitle: "Первый ответ pending — переоткройте или повторите",
            price: 3.49,
            displayPrice: "$3.49",
            scenario: .pending
        ),
        ExampleTokenPackage(
            productID: ProductID(rawValue: "example.tokens.900.cancelled"),
            tokenAmount: 900,
            title: "900 токенов",
            subtitle: "Fixture-отмена без изменения баланса",
            price: 5.49,
            displayPrice: "$5.49",
            scenario: .cancelled
        ),
        ExampleTokenPackage(
            productID: ProductID(rawValue: "example.tokens.1200.failed"),
            tokenAmount: 1200,
            title: "1 200 токенов",
            subtitle: "Provider failure до списания",
            price: 6.99,
            displayPrice: "$6.99",
            scenario: .providerFailure
        ),
        ExampleTokenPackage(
            productID: ProductID(rawValue: "example.tokens.2000.backend"),
            tokenAmount: 2000,
            title: "2 000 токенов",
            subtitle: "Backend error, затем идемпотентный retry",
            price: 9.99,
            displayPrice: "$9.99",
            scenario: .backendFailure
        ),
        ExampleTokenPackage(
            productID: ProductID(rawValue: "example.tokens.5000.offline"),
            tokenAmount: 5000,
            title: "5 000 токенов",
            subtitle: "Offline, затем reconciliation без второго charge",
            price: 19.99,
            displayPrice: "$19.99",
            scenario: .offline
        )
    ]
}
