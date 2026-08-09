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

Для `.restorePurchases` host вызывает monetization restore use case; privacy и terms открывает своим web-router. Footer намеренно ограничен legal/restore-сценариями. Экран оценки приложения и системный review prompt внутри onboarding не поддерживаются. Вне onboarding Rate Us разрешён отдельным app-specific flow.

`BroadOnboardingView` использует semantic fonts, доступные accessibility labels,
вертикальный scroll для маленьких экранов и отключает transition при Reduce Motion.
Внешний вид можно заменить через `BroadOnboardingTheme`; визуальные размеры
стандартной темы проходят через `.scale`, но action и footer hit-area
всегда clamp-ится минимум до `44×44` **немасштабируемых** points.
