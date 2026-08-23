import BroadMonetization
import BroadUIFlows
import SwiftUI

struct ExampleRUPaymentSheetFixtureView: View {
    let initialMethod: CheckoutMethod
    @State private var notice: ExampleRUPaymentNotice?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BroadPaymentMethodSheet(
            methods: [.apple, .sbp, .card],
            product: Self.monthlyProduct,
            initialMethod: initialMethod,
            initialRUDetails: initialMethod == .apple
                ? nil
                : RUCheckoutDetails(
                    acceptsOfferAndPersonalDataProcessing: true,
                    acceptsRecurringCharge: true,
                    receiptEmail: "developer@broadapps.ru"
                ),
            copy: .russian,
            ruConfiguration: AppConfiguration.paywallConfiguration.ruBilling,
            theme: AppTokens.paywallTheme,
            onSubmit: { method, _ in
                notice = ExampleRUPaymentNotice(
                    title: "Безопасный fixture",
                    message: "Выбран способ «\(method.fixtureTitle)». Настоящий платёж не запускался."
                )
            },
            onCancel: { dismiss() }
        )
        .alert(item: $notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("Закрыть")) {
                    dismiss()
                }
            )
        }
    }

    private static let monthlyProduct = MonetizationProduct(
        presentationID: .generated(),
        reference: ProductReference(rawValue: "fixture-ru-monthly-reference"),
        productID: ProductID(rawValue: "fixture.ru.monthly"),
        kind: .autoRenewableSubscription,
        title: "Премиум на месяц",
        subtitle: "Все функции без ограничений",
        price: Money(amount: 699, currencyCode: "RUB"),
        displayPrice: "699 ₽",
        subscriptionPeriod: .month(),
        catalogSource: .ruBackend
    )
}

private struct ExampleRUPaymentNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private extension CheckoutMethod {
    var fixtureTitle: String {
        switch self {
        case .apple: "Apple"
        case .sbp: "СБП"
        case .card: "Банковская карта"
        @unknown default: rawValue
        }
    }
}
