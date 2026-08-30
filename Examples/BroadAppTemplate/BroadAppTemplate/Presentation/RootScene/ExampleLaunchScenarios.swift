import Foundation
import SwiftUI
import UIKit

#if DEBUG
    struct ExampleInAppScenario: Identifiable {
        let route: ExampleScenarioRoute
        let title: String
        let expectedResult: String

        var id: ExampleScenarioRoute {
            route
        }

        static let all = [
            ExampleInAppScenario(
                route: .subscriptionPaywall,
                title: "Subscription paywall",
                expectedResult: "Fixture-каталог открывается без StoreKit-покупки."
            ),
            ExampleInAppScenario(
                route: .tokenPaywall,
                title: "Token paywall",
                expectedResult: "Пакеты токенов и fixture-fulfillment не выдают premium."
            ),
            ExampleInAppScenario(
                route: .specialOffer,
                title: "Special offer",
                expectedResult: "Обычный paywall закрывается, затем показывается отдельное предложение."
            ),
            ExampleInAppScenario(
                route: .ruBilling,
                title: "RU Billing",
                expectedResult: "Выбор Apple, СБП и карты работает без настоящего платежа."
            ),
            ExampleInAppScenario(
                route: .loaderAndErrors,
                title: "Loader и ошибки",
                expectedResult: "Видны мгновенный progress, safe error и повтор запроса."
            ),
            ExampleInAppScenario(
                route: .analytics,
                title: "Аналитика",
                expectedResult: "Typed-события fixture-paywall появляются автоматически."
            ),
            ExampleInAppScenario(
                route: .contactUs,
                title: "Contact Us",
                expectedResult: "Открывается подготовленное письмо или безопасный fallback."
            )
        ]
    }

    struct ExampleLaunchArgumentGroup: Identifiable {
        let title: String
        let arguments: [ExampleLaunchArgument]

        var id: String {
            title
        }

        static let all = [
            ExampleLaunchArgumentGroup(
                title: "Маршрут и onboarding",
                arguments: [
                    .init("-app-flow-main-only", "Сразу открыть main.", "Onboarding и initial paywall пропущены."),
                    .init("-app-flow-paywall-only", "Сразу открыть initial paywall.", "Onboarding пропущен, fixture-paywall загружен."),
                    .init("-initial-paywall-disabled", "Отключить initial paywall.", "После onboarding открывается main без paywall."),
                    .init(
                        "-initial-paywall-every-cold-launch",
                        "Показывать paywall на каждом холодном запуске при inactive access.",
                        "При inactive paywall повторяется после каждого restart."
                    ),
                    .init("-onboarding-one-page", "Оставить одну страницу onboarding.", "Показана ровно одна страница."),
                    .init("-onboarding-two-pages", "Оставить две страницы onboarding.", "Показаны ровно две страницы."),
                    .init("-onboarding-three-pages", "Использовать стандартные три страницы.", "Показаны три страницы fixture-onboarding."),
                    .init(
                        "-onboarding-four-pages",
                        "Показать четыре страницы.",
                        "Четвёртая страница берётся из того же массива конфигурации."
                    ),
                    .init("-onboarding-long", "Проверить длинный onboarding.", "Все дополнительные страницы доступны и не ломают верстку."),
                    .init("-onboarding-custom-ui", "Подключить app-owned renderer.", "Flow использует кастомный SwiftUI onboarding."),
                    .init("-onboarding-disabled", "Отключить onboarding.", "Запуск сразу продолжает initial-paywall policy."),
                    .init(
                        "-onboarding-invalid",
                        "Передать пустую некорректную конфигурацию.",
                        "Flow безопасно сообщает об ошибке конфигурации."
                    ),
                    .init(
                        "-tracking-disabled",
                        "Не запрашивать tracking authorization.",
                        "Onboarding завершается без системного ATT-запроса."
                    )
                ]
            ),
            ExampleLaunchArgumentGroup(
                title: "Paywall, purchase и restore",
                arguments: [
                    .init(
                        "-analytics-fixture",
                        "Открыть fixture-paywall с typed recorder.",
                        "События текущего процесса доступны на экране аналитики."
                    ),
                    .init("-paywall-one-product", "Вернуть один продукт.", "Единственный продукт выбран автоматически."),
                    .init("-paywall-two-products", "Вернуть два продукта.", "Оба продукта показаны в provider order."),
                    .init("-paywall-many-products", "Вернуть двенадцать продуктов.", "Весь список прокручивается без фильтрации."),
                    .init("-paywall-empty", "Вернуть пустой каталог.", "Показано безопасное empty state без CTA покупки."),
                    .init("-paywall-failure", "Сымитировать ошибку загрузки.", "Показаны safe error и кнопка повтора."),
                    .init("-paywall-hard", "Сделать paywall обязательным.", "Кнопка закрытия скрыта согласно hard policy."),
                    .init(
                        "-token-paywall-main-fallback",
                        "Проверить общий резерв token placement на main.",
                        "Остаётся token UI: requested=.tokens, resolved=.main, все продукты consumable."
                    ),
                    .init(
                        "-paywall-payment-methods",
                        "Показать fixture-методы оплаты.",
                        "Доступны Apple, СБП и карта без production checkout."
                    ),
                    .init("-purchase-cancelled", "Сымитировать отмену покупки.", "Нет error и нет ложной выдачи premium."),
                    .init("-purchase-pending", "Сымитировать pending transaction.", "Показано ожидание без premium-доступа."),
                    .init("-purchase-failure", "Сымитировать ошибку покупки.", "Показаны safe diagnostic и возможность повтора."),
                    .init("-restore-nothing", "Восстановление без активной покупки.", "Показан отдельный nothing-found outcome."),
                    .init("-restore-failure", "Сымитировать ошибку restore.", "Показана безопасная ошибка без raw SDK-текста.")
                ]
            ),
            ExampleLaunchArgumentGroup(
                title: "Entitlement и remote features",
                arguments: [
                    .init("-entitlement-active", "Вернуть активный доступ.", "Initial paywall пропущен, открывается main."),
                    .init("-entitlement-inactive", "Вернуть неактивный доступ.", "Маршрут следует выбранной initial-paywall policy."),
                    .init(
                        "-entitlement-unknown",
                        "Вернуть неопределённый доступ.",
                        "Flow не выдаёт premium и использует безопасную политику."
                    ),
                    .init(
                        "-entitlement-timeout",
                        "Сымитировать timeout проверки доступа.",
                        "Нет ложного premium; показан разрешённый fallback."
                    ),
                    .init(
                        "-entitlement-store-kit-fallback",
                        "Проверить fallback к StoreKit fixture.",
                        "Источник доступа меняется без второго purchase flow."
                    ),
                    .init("-special-offer-enabled", "Включить special offer.", "После закрытия main paywall открывается offer placement."),
                    .init("-special-offer-disabled", "Отключить special offer.", "После закрытия main paywall открывается main."),
                    .init(
                        "-special-offer-platform-cache",
                        "Взять offer из platform cache.",
                        "Даже сохранённый true не включает кампанию; открывается main."
                    ),
                    .init(
                        "-special-offer-main-fallback",
                        "Сымитировать fallback offer → main.",
                        "Offer не маскируется обычным main paywall."
                    ),
                    .init(
                        "-special-offer-looping-timer",
                        "Показать визуальный цикл 24 часа.",
                        "Счётчик идёт от 24:00:00 до 00:00:00, затем начинается снова и не закрывает offer."
                    ),
                    .init("-ru-pay-provider-enabled", "Включить RU Pay из provider config.", "Paywall показывает разрешённые RU-методы."),
                    .init("-ru-pay-provider-disabled", "Выключить RU Pay из provider config.", "Явный false оставляет только Apple."),
                    .init(
                        "-ru-pay-adapty-fallback-rejected",
                        "Проверить ru_pay = true без доказанной свежести.",
                        "Adapty managed fallback не разрешает RU-методы; остаётся только Apple."
                    ),
                    .init(
                        "-ru-pay-platform-cache",
                        "Взять RU Pay config из platform cache.",
                        "Даже сохранённый true не включает RU Billing; остаётся только Apple."
                    ),
                    .init(
                        "-ru-region-storefront",
                        "Storefront RU, регион iPhone не RU.",
                        "RU Billing доступен по российскому Storefront."
                    ),
                    .init(
                        "-ru-region-device",
                        "Storefront не RU, регион iPhone RU.",
                        "RU Billing доступен по российскому региону iPhone."
                    ),
                    .init(
                        "-ru-region-neither",
                        "Storefront и регион iPhone не RU.",
                        "RU Billing закрыт; остаётся только Apple."
                    ),
                    .init(
                        "-ru-region-storefront-unavailable-device-ru",
                        "Storefront недоступен, регион iPhone RU.",
                        "RU Billing доступен по региону iPhone."
                    ),
                    .init(
                        "-ru-region-storefront-unavailable-device-non-ru",
                        "Storefront недоступен, регион iPhone не RU.",
                        "RU Billing закрыт; старый Storefront не используется как разрешение."
                    ),
                    .init(
                        "-ru-region-language-only",
                        "Русский язык при нероссийских Storefront и регионе.",
                        "Язык не включает RU Billing; остаётся только Apple."
                    )
                ]
            ),
            ExampleLaunchArgumentGroup(
                title: "Bootstrap и отдельные экраны",
                arguments: [
                    .init("-bootstrap-degraded", "Завершить optional step с ошибкой.", "Main доступен в degraded state."),
                    .init("-bootstrap-failed-once", "Уронить required step один раз.", "Показана ошибка, повтор завершает запуск."),
                    .init("-bootstrap-seed-cache", "Создать fixture-кеш.", "Кеш сохранён для следующего cold-launch сценария."),
                    .init(
                        "-bootstrap-stale-cache",
                        "Сымитировать сеть недоступной при stale cache.",
                        "Main использует последнюю сохранённую конфигурацию."
                    ),
                    .init(
                        "-ru-payment-sheet",
                        "Открыть отдельный RU payment sheet.",
                        "Стартовый метод — СБП, production checkout не запускается."
                    ),
                    .init("-ru-payment-sheet-apple", "Открыть payment sheet с Apple.", "RU-поля и согласия скрыты для Apple."),
                    .init(
                        "-ru-subscription-management",
                        "Открыть управление активной RU-подпиской.",
                        "Показаны status и безопасное fixture-действие отмены."
                    ),
                    .init(
                        "-ru-subscription-cancelled",
                        "Открыть уже отменённую RU-подписку.",
                        "Доступ сохранён до даты, автопродление выключено."
                    ),
                    .init("-live-adapty", "Загрузить live Adapty catalog.", "Разрешены только load/show; purchase и restore отключены.")
                ]
            )
        ]
    }

    struct ExampleLaunchArgument: Identifiable {
        static let xcodePath = "Scheme → Edit Scheme → Run → Arguments"

        let name: String
        let purpose: String
        let expectedResult: String

        var id: String {
            name
        }

        init(
            _ name: String,
            _ purpose: String,
            _ expectedResult: String
        ) {
            self.name = name
            self.purpose = purpose
            self.expectedResult = expectedResult
        }
    }

    struct ExampleLaunchScenariosSections: View {
        let onOpenScenario: (ExampleScenarioRoute) -> Void
        @State private var copiedLaunchArgument: String?
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            Section("Открыть внутри приложения") {
                Text(
                    "Эти сценарии не требуют Scheme и перезапуска: кнопка закроет Debug-настройки и откроет экран из безопасного каталога."
                )
                .font(AppTokens.Font.caption)
                .foregroundStyle(AppTokens.Color.secondaryText)

                ForEach(ExampleInAppScenario.all) { scenario in
                    Button {
                        dismiss()
                        onOpenScenario(scenario.route)
                    } label: {
                        VStack(alignment: .leading, spacing: AppTokens.Spacing.tiny) {
                            Text(scenario.title)
                                .font(AppTokens.Font.cardTitle)
                            Text(scenario.expectedResult)
                                .font(AppTokens.Font.caption)
                                .foregroundStyle(AppTokens.Color.secondaryText)
                        }
                    }
                    .accessibilityIdentifier("debug.open.\(scenario.route.rawValue)")
                }
            }

            Section("Только через холодный запуск") {
                Text(
                    "Launch argument читается при создании процесса. "
                        + "Нажатие Copy не применяет его: добавьте значение "
                        + "в Xcode и полностью перезапустите приложение."
                )
                .font(AppTokens.Font.body)
                Text("В одной взаимоисключающей группе включайте только один аргумент.")
                    .font(AppTokens.Font.caption)
                    .foregroundStyle(AppTokens.Color.warning)
            }

            ForEach(ExampleLaunchArgumentGroup.all) { group in
                Section(group.title) {
                    ForEach(group.arguments) { argument in
                        ExampleLaunchArgumentRow(
                            argument: argument,
                            isCopied: copiedLaunchArgument == argument.name,
                            onCopy: {
                                UIPasteboard.general.string = argument.name
                                copiedLaunchArgument = argument.name
                            }
                        )
                    }
                }
            }
        }
    }

    private struct ExampleLaunchArgumentRow: View {
        let argument: ExampleLaunchArgument
        let isCopied: Bool
        let onCopy: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: AppTokens.Spacing.tiny) {
                HStack(alignment: .firstTextBaseline) {
                    Text(argument.name)
                        .font(AppTokens.Font.fixtureCode)
                        .textSelection(.enabled)
                    Spacer(minLength: AppTokens.Spacing.small)
                    Button(isCopied ? "Скопировано" : "Copy", action: onCopy)
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Скопировать \(argument.name)")
                }

                Text("Назначение: \(argument.purpose)")
                    .font(AppTokens.Font.caption)
                Text("Ожидаемо: \(argument.expectedResult)")
                    .font(AppTokens.Font.caption)
                    .foregroundStyle(AppTokens.Color.secondaryText)
                Label("Перезапуск: обязателен", systemImage: "arrow.clockwise")
                    .font(AppTokens.Font.caption)
                    .foregroundStyle(AppTokens.Color.warning)
                Text(ExampleLaunchArgument.xcodePath)
                    .font(AppTokens.Font.caption)
                    .foregroundStyle(AppTokens.Color.accent)
            }
            .padding(.vertical, AppTokens.Spacing.tiny)
        }
    }
#endif
