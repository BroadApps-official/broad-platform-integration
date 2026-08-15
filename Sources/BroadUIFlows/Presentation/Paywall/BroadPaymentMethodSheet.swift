import BroadMonetization
import SwiftUI

@MainActor
public struct BroadPaymentMethodSheet: View {
    enum Step: Equatable {
        case methods
        case receiptEmail
    }

    @Environment(\.dismiss) var dismiss

    @State var step: Step = .methods
    @State var selectedMethod: CheckoutMethod?
    @State var acceptsOffer = false
    @State var acceptsRecurringCharge = false
    @State var wantsReceipt = false
    @State var receiptEmail: String
    @FocusState var isEmailFocused: Bool

    let methods: [CheckoutMethod]
    let product: MonetizationProduct
    let copy: BroadPaywallCopy
    let ruConfiguration: BroadRUBillingPresentationConfiguration
    let theme: BroadPaywallTheme
    let receiptEmailStore: (any BroadReceiptEmailStoreProtocol)?
    let onSubmit: @MainActor (CheckoutMethod, CheckoutOptions) -> Void
    let onCancel: @MainActor () -> Void

    public init(
        methods: [CheckoutMethod],
        product: MonetizationProduct,
        initialMethod: CheckoutMethod? = nil,
        initialRUDetails: RUCheckoutDetails? = nil,
        copy: BroadPaywallCopy,
        ruConfiguration: BroadRUBillingPresentationConfiguration? = nil,
        theme: BroadPaywallTheme,
        receiptEmailStore: (any BroadReceiptEmailStoreProtocol)? = nil,
        onSubmit: @escaping @MainActor (
            CheckoutMethod,
            CheckoutOptions
        ) -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        precondition(
            Set(methods.map(\.rawValue)).count == methods.count,
            "Payment method sheet does not accept duplicates"
        )
        precondition(
            initialMethod.map(methods.contains) != false,
            "Initial payment method must be present in the sheet"
        )

        let resolvedRUConfiguration = ruConfiguration
            ?? BroadRUBillingPresentationConfiguration()
        let savedEmail = initialRUDetails?.receiptEmail ?? ""

        self.methods = methods
        self.product = product
        self.copy = copy
        self.ruConfiguration = resolvedRUConfiguration
        self.theme = theme
        self.receiptEmailStore = receiptEmailStore
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        _selectedMethod = State(
            initialValue: initialMethod
                ?? (methods.count == 1 ? methods.first : nil)
        )
        _acceptsOffer = State(
            initialValue:
            initialRUDetails?.acceptsOfferAndPersonalDataProcessing ?? false
        )
        _acceptsRecurringCharge = State(
            initialValue: initialRUDetails?.acceptsRecurringCharge ?? false
        )
        _wantsReceipt = State(
            initialValue: initialRUDetails?.receiptEmail != nil
        )
        _receiptEmail = State(initialValue: savedEmail)
    }
}

extension BroadPaymentMethodSheet {
    var isRUSelection: Bool {
        selectedMethod == .sbp || selectedMethod == .card
    }

    var requiresRecurringConsent: Bool {
        product.kind == .autoRenewableSubscription
    }

    var isReceiptEmailValid: Bool {
        let value = receiptEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2,
              !parts[0].isEmpty,
              parts[1].contains("."),
              !parts[1].hasPrefix("."),
              !parts[1].hasSuffix(".")
        else {
            return false
        }
        return !value.contains(where: \.isWhitespace)
    }

    var canAdvanceFromMethods: Bool {
        guard selectedMethod != nil else {
            return false
        }
        guard isRUSelection else {
            return true
        }
        return acceptsOffer
            && (!requiresRecurringConsent || acceptsRecurringCharge)
    }

    var isPrimaryActionEnabled: Bool {
        switch step {
        case .methods:
            canAdvanceFromMethods
        case .receiptEmail:
            isReceiptEmailValid
        }
    }

    var recurringConsentTitle: String {
        let price = product.displayPrice ?? "—"
        let period = BroadRUBillingPeriodFormatter.russian(
            product.subscriptionPeriod
        )
        return "\(ruConfiguration.copy.recurringConsentPrefix): \(price) \(period)"
            .trimmingCharacters(in: .whitespaces)
    }

    var headerTitle: String {
        switch step {
        case .methods:
            copy.checkout.title
        case .receiptEmail:
            ruConfiguration.copy.emailTitle
        }
    }

    var primaryActionTitle: String {
        if step == .receiptEmail || isRUSelection {
            return ruConfiguration.copy.continueTitle
        }
        return copy.actions.purchaseTitle
    }

    func primaryAction() {
        switch step {
        case .methods:
            guard canAdvanceFromMethods else {
                return
            }
            if isRUSelection, wantsReceipt {
                step = .receiptEmail
            } else {
                submit()
            }
        case .receiptEmail:
            submit()
        }
    }

    func returnToMethods() {
        isEmailFocused = false
        step = .methods
    }

    func cancelAndDismiss() {
        isEmailFocused = false
        onCancel()
        dismiss()
    }

    func submit() {
        guard let selectedMethod else {
            return
        }
        guard selectedMethod == .apple || canAdvanceFromMethods else {
            return
        }
        guard selectedMethod == .apple || !wantsReceipt || isReceiptEmailValid else {
            return
        }

        let options: CheckoutOptions
        if selectedMethod == .apple {
            options = .standard
        } else {
            let normalizedEmail = receiptEmail.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if wantsReceipt, let receiptEmailStore {
                let storageKey = ruConfiguration.receiptEmailStorageKey
                Task {
                    await receiptEmailStore.saveEmail(
                        normalizedEmail,
                        forKey: storageKey
                    )
                }
            }
            options = CheckoutOptions(
                ruDetails: RUCheckoutDetails(
                    acceptsOfferAndPersonalDataProcessing: acceptsOffer,
                    acceptsRecurringCharge: acceptsRecurringCharge,
                    receiptEmail: wantsReceipt ? normalizedEmail : nil
                )
            )
        }

        onSubmit(selectedMethod, options)
        dismiss()
    }

    func loadSavedReceiptEmailIfNeeded() async {
        guard receiptEmail.isEmpty, let receiptEmailStore,
              let savedEmail = await receiptEmailStore.loadEmail(
                  forKey: ruConfiguration.receiptEmailStorageKey
              )
        else {
            return
        }
        receiptEmail = savedEmail
    }
}
