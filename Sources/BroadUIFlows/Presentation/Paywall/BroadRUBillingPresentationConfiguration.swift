import Foundation

public struct BroadRUBillingCopy: Equatable, Sendable {
    public let continueTitle: String
    public let offerConsentTitle: String
    public let recurringConsentPrefix: String
    public let receiptTitle: String
    public let emailTitle: String
    public let emailPlaceholder: String
    public let invalidEmailMessage: String
    public let requiredMark: String

    public init(
        continueTitle: String,
        offerConsentTitle: String,
        recurringConsentPrefix: String,
        receiptTitle: String,
        emailTitle: String,
        emailPlaceholder: String,
        invalidEmailMessage: String,
        requiredMark: String = "Обязательно"
    ) {
        self.continueTitle = continueTitle
        self.offerConsentTitle = offerConsentTitle
        self.recurringConsentPrefix = recurringConsentPrefix
        self.receiptTitle = receiptTitle
        self.emailTitle = emailTitle
        self.emailPlaceholder = emailPlaceholder
        self.invalidEmailMessage = invalidEmailMessage
        self.requiredMark = requiredMark
    }

    public static let russian = BroadRUBillingCopy(
        continueTitle: "Продолжить",
        offerConsentTitle:
        "Я принимаю условия оферты и даю согласие на обработку персональных данных",
        recurringConsentPrefix: "Я согласен на регулярные списания",
        receiptTitle: "Получить кассовый чек на email",
        emailTitle: "Email для чека",
        emailPlaceholder: "name@example.com",
        invalidEmailMessage: "Введите корректный email"
    )
}

/// App-specific presentation data for the Russian payment flow. The platform
/// owns validation and UI; the host can override copy and receipt email storage.
public struct BroadRUBillingPresentationConfiguration: Equatable, Sendable {
    public let copy: BroadRUBillingCopy
    public let receiptEmailStorageKey: String

    public init(
        copy: BroadRUBillingCopy = .russian,
        receiptEmailStorageKey: String = "broad.ru-billing.receipt-email"
    ) {
        precondition(
            !receiptEmailStorageKey.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty,
            "RU billing receipt email key must not be empty"
        )
        self.copy = copy
        self.receiptEmailStorageKey = receiptEmailStorageKey
    }
}
