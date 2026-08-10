public extension BroadPaywallCopy {
    static let russian = BroadPaywallCopy(
        header: Header(
            title: "Выберите тариф",
            subtitle: "Можно изменить или отменить позже."
        ),
        products: Products(
            fallbackTitle: "Премиум-доступ",
            unavailablePriceTitle: "Цена недоступна",
            selectedAccessibilityValue: "Выбрано"
        ),
        actions: Actions(
            purchaseTitle: "Продолжить",
            restoreTitle: "Восстановить покупки",
            restoringTitle: "Восстанавливаем покупки",
            retryTitle: "Повторить",
            closeAccessibilityLabel: "Закрыть пейвол",
            cancelTitle: "Отмена"
        ),
        states: States(
            loadingTitle: "Загружаем тарифы",
            errorTitle: "Тарифы временно недоступны",
            emptyTitle: "Нет доступных тарифов",
            emptyMessage: "Закройте экран или повторите попытку позже.",
            checkoutUnavailableMessage: "Этот способ оплаты временно недоступен.",
            nothingToRestoreMessage: "Покупки для восстановления не найдены.",
            purchase: BroadPaywallPurchaseStateCopy(
                pendingMessage: "Платёж ожидает подтверждения.",
                completedMessage: "Покупка завершена.",
                completedButUnverifiedMessage:
                "Покупка завершена, но доступ пока не подтверждён."
            )
        ),
        checkout: Checkout(
            title: "Выберите способ оплаты",
            appleTitle: "App Store",
            sbpTitle: "СБП",
            cardTitle: "Банковская карта"
        )
    )
}
