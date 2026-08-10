import BroadMonetization
import SwiftUI

@MainActor
public struct BroadPaymentMethodSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMethod: CheckoutMethod?
    @State private var acceptsOffer = false
    @State private var acceptsRecurringCharge = false
    @State private var wantsReceipt = false
    @State private var receiptEmail: String
    @FocusState private var isEmailFocused: Bool

    private let methods: [CheckoutMethod]
    private let product: MonetizationProduct
    private let copy: BroadPaywallCopy
    private let ruConfiguration: BroadRUBillingPresentationConfiguration
    private let theme: BroadPaywallTheme
    private let receiptEmailStore: (any BroadReceiptEmailStoreProtocol)?
    private let onSubmit: @MainActor (CheckoutMethod, CheckoutOptions) -> Void
    private let onCancel: @MainActor () -> Void

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
            ?? BroadRUBillingPresentationConfiguration(legalLinks: [])
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

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.metrics.spacing.content) {
                Text(copy.checkout.title)
                    .font(theme.typography.title)
                    .foregroundStyle(theme.palette.primaryText)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: theme.metrics.spacing.product) {
                    ForEach(methods, id: \.rawValue) { method in
                        paymentMethodButton(method)
                    }
                }

                if isRUSelection {
                    ruRequirements
                }

                submitButton

                Button(copy.actions.cancelTitle) {
                    onCancel()
                    dismiss()
                }
                .font(theme.typography.action)
                .foregroundStyle(theme.palette.secondaryText)
                .frame(
                    maxWidth: .infinity,
                    minHeight: BroadPaywallTheme.Sizing.minimumInteractiveDimension
                )
                .buttonStyle(BroadNoPressEffectButtonStyle())
            }
            .padding(theme.metrics.spacing.screen)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.palette.background.ignoresSafeArea())
        .task {
            await loadSavedReceiptEmailIfNeeded()
        }
    }
}

private extension BroadPaymentMethodSheet {
    private var isRUSelection: Bool {
        selectedMethod == .sbp || selectedMethod == .card
    }

    private var requiresRecurringConsent: Bool {
        product.kind == .autoRenewableSubscription
    }

    private var isReceiptEmailValid: Bool {
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

    private var canSubmit: Bool {
        guard selectedMethod != nil else {
            return false
        }
        guard isRUSelection else {
            return true
        }
        return acceptsOffer
            && (!requiresRecurringConsent || acceptsRecurringCharge)
            && (!wantsReceipt || isReceiptEmailValid)
    }

    private var ruRequirements: some View {
        VStack(alignment: .leading, spacing: theme.metrics.spacing.product) {
            consentRow(
                isAccepted: $acceptsOffer,
                title: ruConfiguration.copy.offerConsentTitle,
                isRequired: true
            )

            if !ruConfiguration.legalLinks.isEmpty {
                VStack(alignment: .leading, spacing: theme.metrics.spacing.text) {
                    ForEach(ruConfiguration.legalLinks) { link in
                        Link(link.title, destination: link.url)
                            .font(theme.typography.footer)
                            .foregroundStyle(theme.palette.accent)
                            .accessibilityLabel(
                                link.accessibilityLabel ?? link.title
                            )
                    }
                }
                .padding(.leading, BroadPaywallTheme.Sizing.minimumInteractiveDimension)
            }

            if requiresRecurringConsent {
                consentRow(
                    isAccepted: $acceptsRecurringCharge,
                    title: recurringConsentTitle,
                    isRequired: true
                )
            }

            consentRow(
                isAccepted: $wantsReceipt,
                title: ruConfiguration.copy.receiptTitle,
                isRequired: false
            )

            if wantsReceipt {
                VStack(alignment: .leading, spacing: theme.metrics.spacing.text) {
                    Text(ruConfiguration.copy.emailTitle)
                        .font(theme.typography.productDetail)
                        .foregroundStyle(theme.palette.primaryText)

                    TextField(
                        ruConfiguration.copy.emailPlaceholder,
                        text: $receiptEmail
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .focused($isEmailFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        isEmailFocused = false
                    }
                    .padding(theme.metrics.spacing.productContent)
                    .background(
                        RoundedRectangle(
                            cornerRadius: theme.metrics.sizing.cornerRadius,
                            style: .continuous
                        )
                        .fill(theme.palette.surface)
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: theme.metrics.sizing.cornerRadius,
                            style: .continuous
                        )
                        .stroke(
                            receiptEmail.isEmpty || isReceiptEmailValid
                                ? theme.palette.border
                                : Color.red,
                            lineWidth: theme.metrics.sizing.borderWidth
                        )
                    }

                    if !receiptEmail.isEmpty, !isReceiptEmailValid {
                        Text(ruConfiguration.copy.invalidEmailMessage)
                            .font(theme.typography.footer)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.leading, BroadPaywallTheme.Sizing.minimumInteractiveDimension)
            }
        }
    }

    private var recurringConsentTitle: String {
        let price = product.displayPrice ?? "—"
        let period = BroadRUBillingPeriodFormatter.russian(
            product.subscriptionPeriod
        )
        return "\(ruConfiguration.copy.recurringConsentPrefix): \(price) \(period)"
            .trimmingCharacters(in: .whitespaces)
    }

    private var submitButton: some View {
        Button {
            submit()
        } label: {
            Text(
                isRUSelection
                    ? ruConfiguration.copy.continueTitle
                    : copy.actions.purchaseTitle
            )
            .font(theme.typography.action)
            .foregroundStyle(theme.palette.actionForeground)
            .frame(
                maxWidth: .infinity,
                minHeight: theme.metrics.sizing.minimumActionHeight
            )
            .background(
                RoundedRectangle(
                    cornerRadius: theme.metrics.sizing.cornerRadius,
                    style: .continuous
                )
                .fill(theme.palette.accent.opacity(canSubmit ? 1 : 0.35))
            )
            .contentShape(Rectangle())
        }
        .disabled(!canSubmit)
        .buttonStyle(BroadNoPressEffectButtonStyle())
    }

    private func paymentMethodButton(_ method: CheckoutMethod) -> some View {
        BroadPaymentMethodRow(
            method: method,
            isSelected: selectedMethod == method,
            title: copy.checkout.title(for: method),
            theme: theme
        ) {
            selectedMethod = method
            isEmailFocused = false
        }
    }

    private func consentRow(
        isAccepted: Binding<Bool>,
        title: String,
        isRequired: Bool
    ) -> some View {
        Button {
            isAccepted.wrappedValue.toggle()
        } label: {
            HStack(alignment: .top, spacing: theme.metrics.spacing.productContent) {
                Image(
                    systemName: isAccepted.wrappedValue
                        ? "checkmark.square.fill"
                        : "square"
                )
                .font(theme.typography.productTitle)
                .foregroundStyle(
                    isAccepted.wrappedValue
                        ? theme.palette.accent
                        : theme.palette.secondaryText
                )
                .frame(
                    width: BroadPaywallTheme.Sizing.minimumInteractiveDimension,
                    height: BroadPaywallTheme.Sizing.minimumInteractiveDimension
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(theme.typography.productDetail)
                        .foregroundStyle(theme.palette.primaryText)
                        .multilineTextAlignment(.leading)

                    if isRequired {
                        Text(ruConfiguration.copy.requiredMark)
                            .font(theme.typography.footer)
                            .foregroundStyle(theme.palette.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(BroadNoPressEffectButtonStyle())
    }

    private func submit() {
        guard let selectedMethod, canSubmit else {
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

    private func loadSavedReceiptEmailIfNeeded() async {
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
