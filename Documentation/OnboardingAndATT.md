# Configurable onboarding и ATT

`BroadUIFlows` показывает onboarding из конфигурации приложения, а `BroadCore` изолирует системный ATT API за Domain-контрактом. Loader, bootstrap и `AppFlowCoordinator` разрешение не запрашивают.

## Гарантированный момент запроса

ATT-задача появляется только когда одновременно выполнены все условия:

1. onboarding находится на экране;
2. фактически появился первый слайд;
3. первым остаётся текущий слайд;
4. `scenePhase == .active`;
5. SwiftUI-view уже прикреплена к `UIWindow`, у которого
   `isHidden == false`, `alpha > 0` и scene в `.foregroundActive`;
6. прошла задержка из `OnboardingTrackingAuthorizationPolicy`;
7. системный статус всё ещё `.notDetermined`.

`OnboardingViewModel` держит не более одной ожидающей задачи. Уход со
слайда, lifecycle callback о потере active/visible-состояния или
исчезновение onboarding отменяют ожидание. Непосредственно после delay
ViewModel ещё раз синхронно читает текущие `UIWindow.isHidden`, `alpha`
и `activationState` через weak live-validator. Поэтому скрытие или fade-out
окна между первым callback и deadline fail-closed блокирует prompt. После
фактической попытки повторного системного запроса в этой сесии ViewModel
не создаёт.

## Info.plist

Host app обязан добавить понятный пользователю текст:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>Этот доступ помогает показывать более релевантную рекламу.</string>
```

Без ключа нельзя включать policy `.afterFirstSlide`. Текст локализуется и принадлежит приложению.

## Composition root

`BroadCoreAssembly` по умолчанию регистрирует `SystemTrackingAuthorizationAdapter` и `TrackingAuthorizationUseCaseProtocol`. Для preview или собственной инфраструктуры можно передать другую реализацию `TrackingAuthorizationRepositoryProtocol`.

```swift
let coreAssembly = BroadCoreAssembly(
    bootstrapSteps: bootstrapSteps
)

let trackingUseCase = resolver.resolve(
    TrackingAuthorizationUseCaseProtocol.self
)!

let onboardingViewModel = OnboardingViewModel(
    configuration: onboardingConfiguration,
    requestTrackingAuthorizationUseCase: trackingUseCase
)
```

Создание зависимостей остаётся в composition root. `View` не обращается к Swinject.

## Конфигурация

Количество страниц, стабильные ID, весь текст и media ID задаёт приложение. Платформа не знает имён assets и не ограничивает renderer статичной картинкой.

`pages` — единственный источник количества. Отдельный `slidesCount` намеренно
не существует: он мог бы разойтись с массивом. Один элемент массива означает
один слайд; добавление или удаление элемента не требует изменения
`BroadUIFlows`.

> [!IMPORTANT]
> Три страницы в `BroadAppTemplate` — только короткий демонстрационный набор.
> Это не лимит и не значение по умолчанию.

```swift
let onboardingConfiguration = OnboardingConfiguration(
    pages: [
        OnboardingPageConfiguration(
            id: "welcome",
            title: AppTexts.onboardingWelcomeTitle,
            subtitle: AppTexts.onboardingWelcomeSubtitle,
            media: OnboardingMediaDescriptor(identifier: "welcome-animation")
        ),
        OnboardingPageConfiguration(
            id: "features",
            title: AppTexts.onboardingFeaturesTitle,
            subtitle: AppTexts.onboardingFeaturesSubtitle,
            media: OnboardingMediaDescriptor(identifier: "features-illustration")
        )
    ],
    continueTitle: AppTexts.continueTitle,
    completionTitle: AppTexts.startTitle,
    progressAccessibilityLabel: AppTexts.onboardingProgress,
    footerLinks: [
        OnboardingFooterLinkConfiguration(
            destination: .privacyPolicy,
            title: AppTexts.privacyTitle
        ),
        OnboardingFooterLinkConfiguration(
            destination: .restorePurchases,
            title: AppTexts.restoreTitle
        ),
        OnboardingFooterLinkConfiguration(
            destination: .termsOfUse,
            title: AppTexts.termsTitle
        )
    ],
    trackingAuthorizationPolicy: .afterFirstSlide(
        delay: .milliseconds(400)
    )
)
```

Если приложению не нужен ATT, используется `.disabled`. Значение по умолчанию
тоже `.disabled`. Нулевой или отрицательный delay для `.afterFirstSlide`
считается невалидной policy: factory без краша возвращает `.disabled`,
а не запрашивает ATT немедленно.

Конфигурация валидируется без `precondition`-краша. Пустой список страниц,
пустые ID/тексты/media ID, повторяющиеся page ID или footer destination дают
typed `validationError`. Готовый renderer один раз безопасно вызывает
`onCompleted`, ничего не рисует и главное — не планирует ATT. Поэтому битый
remote/app config не оставляет пользователя на пустом экране и не завершает
процесс.

## View

### Вариант 1. Стандартная композиция

```swift
BroadOnboardingView(
    viewModel: onboardingViewModel,
    media: { descriptor in
        OnboardingMediaView(identifier: descriptor.identifier)
    },
    onFooterAction: handleOnboardingFooter,
    onCompleted: appFlowCoordinator.onboardingCompleted
)
```

`BroadOnboardingView` строит progress через весь массив страниц, поэтому
одинаково работает с одной, четырьмя или длинным списком. Через `theme` и
`media` приложение подставляет свои визуальные значения, не меняя переходы и
ATT.

### Вариант 2. Полностью свой SwiftUI

Если расположение элементов из Figma/no-code дизайна не совпадает со
стандартным экраном, не скрывайте `BroadOnboardingView` и не повторяйте его
lifecycle вручную. Используйте logic-only host:

```swift
BroadOnboardingFlowHost(
    viewModel: onboardingViewModel,
    onCompleted: appFlowCoordinator.onboardingCompleted
) { viewModel, actions in
    MyBrandOnboardingScreen(
        page: viewModel.currentPage,
        currentPage: viewModel.currentIndex + 1,
        pageCount: viewModel.configuration.pages.count,
        isLastPage: viewModel.isLastPage,
        onContinue: actions.advance
    )
}
```

Приложение полностью рисует `MyBrandOnboardingScreen`. Host оставляет у
платформы только общую логику:

- наблюдение за текущей страницей;
- переход и завершение на последнем элементе `pages`;
- обработку пустой или невалидной конфигурации;
- active/window lifecycle;
- ATT только после появления первой страницы.

### Как определить страницы до реализации

Сначала сопоставьте Kaiten, Figma/no-code материалы, техническое задание и
reference. Если список однозначен — выпишите его и создайте `pages`. Если
количество или содержимое не указано либо источники противоречат друг другу,
задайте вопрос до написания UI:

> Сколько должно быть слайдов и что находится на каждом: заголовок, текст,
> изображение и действие кнопки?

Стабильный технический `id` для каждой найденной страницы разработчик или агент
создаёт сам из её смысла, например `welcome`, `features`, `examples`. Это не
продуктовый вопрос и не причина останавливать работу повторно.

Нельзя молча использовать три страницы example. Если onboarding не нужен,
отключите его через `AppFlowConfiguration`, а не передавайте пустой массив.
Пустой массив предназначен только для безопасной обработки ошибочной
конфигурации. При отключённом onboarding первый слайд не появляется, поэтому
ATT не запрашивается.

Для `.restorePurchases` host вызывает monetization restore use case; privacy и terms открывает своим web-router. Footer намеренно ограничен legal/restore-сценариями. Экран оценки приложения и системный review prompt внутри onboarding не поддерживаются. Вне onboarding Rate Us разрешён отдельным app-specific flow.

`BroadOnboardingView` использует semantic fonts, доступные accessibility labels,
вертикальный scroll для маленьких экранов и отключает transition при Reduce Motion.
Внешний вид можно заменить через `BroadOnboardingTheme`; визуальные размеры
стандартной темы проходят через `.scale`, но action и footer hit-area
всегда clamp-ится минимум до `44×44` **немасштабируемых** points.
