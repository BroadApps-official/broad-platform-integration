import BroadMonetization
import BroadUIFlows
import SwiftUI

struct ExampleRUPaymentSheetFixtureView: View {
    let initialMethod: CheckoutMethod

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
            theme: .standard,
            onSubmit: { _, _ in },
            onCancel: {}
        )
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
