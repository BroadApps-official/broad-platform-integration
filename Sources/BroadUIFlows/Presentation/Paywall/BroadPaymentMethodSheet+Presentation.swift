import BroadMonetization
import SwiftUI

public extension BroadPaymentMethodSheet {
    var body: some View {
        ZStack {
            theme.palette.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    sheetContent
                        .frame(
                            maxWidth: theme.metrics.sizing.maximumContentWidth,
                            alignment: .leading
                        )
                        .padding(.horizontal, theme.metrics.spacing.screen)
                        .padding(.bottom, theme.metrics.spacing.content)
                        .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionFooter
        }
        .animation(.easeInOut(duration: 0.2), value: step)
        .task {
            await loadSavedReceiptEmailIfNeeded()
        }
    }
}

private extension BroadPaymentMethodSheet {
    var header: some View {
        HStack(alignment: .center, spacing: theme.metrics.spacing.productContent) {
            if step == .receiptEmail {
                headerButton(
                    systemName: "chevron.left",
                    accessibilityLabel: copy.actions.cancelTitle,
                    action: returnToMethods
                )
            }

            Text(headerTitle)
                .font(theme.typography.title)
                .foregroundStyle(theme.palette.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: theme.metrics.spacing.text)

            headerButton(
                systemName: "xmark",
                accessibilityLabel: copy.actions.closeAccessibilityLabel,
                action: cancelAndDismiss
            )
        }
        .frame(maxWidth: theme.metrics.sizing.maximumContentWidth)
        .padding(.horizontal, theme.metrics.spacing.screen)
        .padding(.top, theme.metrics.spacing.header)
        .padding(.bottom, theme.metrics.spacing.content)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    var sheetContent: some View {
        switch step {
        case .methods:
            methodsContent
        case .receiptEmail:
            receiptEmailContent
        }
    }

    var methodsContent: some View {
        VStack(alignment: .leading, spacing: theme.metrics.spacing.content) {
            VStack(spacing: theme.metrics.spacing.product) {
                ForEach(methods, id: \.rawValue) { method in
                    paymentMethodButton(method)
                }
            }

            if isRUSelection {
                ruRequirements
            }
        }
    }

    var ruRequirements: some View {
        VStack(alignment: .leading, spacing: theme.metrics.spacing.product) {
            consentRow(
                isAccepted: $acceptsOffer,
                title: ruConfiguration.copy.offerConsentTitle,
                isRequired: true
            )

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
        }
    }

    var receiptEmailContent: some View {
        VStack(alignment: .leading, spacing: theme.metrics.spacing.content) {
            Text(ruConfiguration.copy.receiptTitle)
                .font(theme.typography.subtitle)
                .foregroundStyle(theme.palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: theme.metrics.spacing.text) {
                Text(ruConfiguration.copy.emailTitle)
                    .font(theme.typography.productDetail)
                    .foregroundStyle(theme.palette.primaryText)

                TextField(
                    ruConfiguration.copy.emailPlaceholder,
                    text: $receiptEmail
                )
                .font(theme.typography.productTitle)
                .foregroundStyle(theme.palette.primaryText)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .focused($isEmailFocused)
                .submitLabel(.done)
                .onSubmit {
                    if isReceiptEmailValid {
                        submit()
                    }
                }
                .padding(theme.metrics.spacing.productContent)
                .frame(
                    minHeight: max(
                        theme.metrics.sizing.minimumActionHeight,
                        BroadPaywallTheme.Sizing.minimumInteractiveDimension
                    )
                )
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
        }
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                isEmailFocused = true
            }
        }
    }

    var actionFooter: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            BroadPaywallPrimaryButton(
                title: primaryActionTitle,
                isEnabled: isPrimaryActionEnabled,
                isInFlight: false,
                theme: theme,
                action: primaryAction
            )
            .frame(maxWidth: theme.metrics.sizing.maximumContentWidth)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, theme.metrics.spacing.screen)
        .padding(.top, theme.metrics.spacing.footer)
        .padding(.bottom, theme.metrics.spacing.screen)
        .background(theme.palette.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.palette.border)
                .frame(height: theme.metrics.sizing.borderWidth)
                .shadow(color: .black.opacity(0.08), radius: 8, y: -4)
        }
    }

    func headerButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(theme.typography.action)
                .foregroundStyle(theme.palette.primaryText)
                .frame(
                    width: BroadPaywallTheme.Sizing.minimumInteractiveDimension,
                    height: BroadPaywallTheme.Sizing.minimumInteractiveDimension
                )
                .background(
                    Circle()
                        .fill(theme.palette.surface)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(BroadNoPressEffectButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    func paymentMethodButton(_ method: CheckoutMethod) -> some View {
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

    func consentRow(
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

                VStack(alignment: .leading, spacing: theme.metrics.spacing.text) {
                    Text(title)
                        .font(theme.typography.productDetail)
                        .foregroundStyle(theme.palette.primaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if isRequired {
                        Text(ruConfiguration.copy.requiredMark)
                            .font(theme.typography.footer)
                            .foregroundStyle(theme.palette.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, theme.metrics.spacing.text)
            .padding(.vertical, theme.metrics.spacing.text)
            .background(
                RoundedRectangle(
                    cornerRadius: theme.metrics.sizing.cornerRadius,
                    style: .continuous
                )
                .fill(theme.palette.surface)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(BroadNoPressEffectButtonStyle())
    }
}
