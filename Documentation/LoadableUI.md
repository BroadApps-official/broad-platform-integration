# Loader, error, empty и retry

`BroadUIFlows` содержит готовые SwiftUI-компоненты и исчерпывающий renderer над `LoadableState<Value>`. Компоненты отвечают только за отображение. Они не запускают запросы, не создают `Task`, не знают о repository/SDK, не обращаются к Swinject и никогда не вызывают ATT или Apple Review.

## Где лежит

```text
Sources/BroadUIFlows/Presentation/Loadable/
├── BroadLoadableView.swift          # state → UI
├── BroadLoaderView.swift            # первая загрузка
├── BroadRefreshIndicator.swift      # неблокирующий refresh
├── BroadEmptyView.swift             # успешный пустой результат
├── BroadErrorView.swift             # блокирующая ошибка + retry
├── BroadStaleBanner.swift            # разрешённый stale fallback
├── BroadStateContent.swift           # app-specific текст и SF Symbol
├── BroadActionConfiguration.swift    # действие и in-flight state
└── BroadLoadableTokens.swift          # тема, typography и scaled metrics
```

SwiftUI value types не регистрируются в `BroadUIFlowsAssembly`. Host создаёт их прямо в `View` и передаёт все зависимости через `init`.

## Готовые компоненты

| Компонент | Когда использовать | Что передаёт приложение |
|---|---|---|
| `BroadLoaderView` | Первая загрузка без рабочего значения | title, message, theme и необязательный custom media view |
| `BroadRefreshIndicator` | Повторная загрузка поверх уже показанного content | accessibility label и theme |
| `BroadEmptyView` | Запрос успешен, но показывать нечего | title, message, icon и необязательное действие |
| `BroadErrorView` | Блокирующая ошибка | безопасный user message, icon и необязательный retry |
| `BroadStaleBanner` | Feature явно разрешила cached/stale fallback | title, message, icon и необязательный retry |
| `BroadLoadableView` | Единая маршрутизация всех состояний | state и builders для каждого результата |

В платформе нет встроенных продуктовых текстов, asset names или решений о retry. `BroadStateContent` заполняет host app. `systemImageName` предназначен для SF Symbols; app-specific loader image передаётся через `media` builder.

```swift
BroadLoaderView(
    content: BroadStateContent(
        title: texts.loadingTitle,
        message: texts.loadingMessage
    ),
    theme: appLoadableTheme
) {
    Image("loader-illustration")
        .resizable()
        .scaledToFit()
}
```

Custom media считается декоративным: доступное название состояния всегда приходит через `title/message`.

## Точная маршрутизация состояний

`BroadLoadableView` не читает `state.value` как универсальный shortcut. Он переключает enum исчерпывающе:

| `LoadableState` | Что отображается |
|---|---|
| `idle` | `idle()` |
| `loading(previousValue: nil)` | `loading()` |
| `loading(previousValue: value)` | прежний `content(value)` + `refreshIndicator()` |
| `loaded(value)` | `content(value)` |
| `empty` | `empty()` |
| `stale(value, error)` | `staleBanner(error)` + рабочий `content(value)` |
| `error(error, previousValue)` | только `failure(error, previousValue)` |

У `loaded`, refresh с previous value и `stale` одна structural content-ветка. Поэтому SwiftUI не пересоздаёт рабочее дерево только из-за смены freshness-state. Refresh indicator не блокирует касания, не меняет opacity и не затемняет content.

`error(previousValue:)` намеренно не показывает previous content автоматически. Это блокирующая ошибка. Если конкретному экрану безопасно оставить старое значение для контекста, host делает это явно внутри `failure` builder. Для entitlement/paywall нельзя принимать такое решение по одному факту наличия previous value.

## Пример подключения

```swift
BroadLoadableView(
    state: viewModel.state,
    content: { value in
        FeatureContent(value: value)
    },
    idle: {
        EmptyView()
    },
    loading: {
        BroadLoaderView(content: texts.loaderContent)
    },
    refreshIndicator: {
        BroadRefreshIndicator(
            accessibilityLabel: texts.refreshingAccessibilityLabel
        )
    },
    empty: {
        BroadEmptyView(content: texts.emptyContent)
    },
    staleBanner: { error in
        BroadStaleBanner(
            content: BroadStateContent(
                title: texts.offlineTitle,
                message: error?.userMessage ?? texts.cachedValueMessage,
                systemImageName: "wifi.slash"
            )
        )
    },
    failure: { error, _ in
        BroadErrorView(
            content: BroadStateContent(
                title: texts.errorTitle,
                message: error.userMessage,
                systemImageName: "exclamationmark.triangle.fill"
            ),
            retry: error.isRetryable ? viewModel.retryConfiguration : nil
        )
    }
)
```

`AppError.userMessage` уже должен быть безопасным локализованным сообщением. `diagnosticCode`, raw SDK error и `localizedDescription` в UI не выводятся.

## Retry без двойного запуска

`BroadActionConfiguration` хранит только UI-состояние действия и синхронный
`@MainActor` callback. Публичный `BroadActionButton` сразу показывает системный
`ProgressView` и отключается, когда `isInFlight == true`. ViewModel остаётся
окончательным владельцем single-flight и должен синхронно поставить guard и
изменить UI-state **до** создания `Task`:

```swift
func retry() {
    guard !isRetrying else {
        return
    }

    isRetrying = true
    state = state.beginLoading()
    retryTask = Task { await reload() }
}
```

Передавайте `isInFlight: true`, пока операция выполняется. Это правило действует
не только для Retry: «Сгенерировать», «Найти», «Отправить» и другие
backend-кнопки обязаны дать мгновенный визуальный ответ ещё до перехода на
полноэкранный loader. Renderer сам не повторяет запрос на `onAppear` и не владеет
cancellation. Готовый пример: [Debug и async-действия](DebugToolsAndAsyncActions.md).

## Theme и layout

`BroadLoadableTheme.standard` использует semantic system colors, Dynamic Type fonts и размеры через локальный `.scale`. Приложение может передать собственные `Palette`, `Typography` и `Metrics`; размеры host theme должны приходить уже масштабированными через его design tokens.

Компоненты не задают фиксированную высоту тексту. Stale banner переходит из horizontal в vertical layout на accessibility Dynamic Type. Декоративные иконки скрыты от VoiceOver, loader остаётся нативным progress element, а action — отдельной доступной кнопкой с minimum tap target. Custom animation отсутствует, поэтому Reduce Motion не требует альтернативной ветки; системный `ProgressView` остаётся системным.

## Timeout, degraded и fallback

Loader не запускает собственный timeout. Timeout/retry policy принадлежит use case/bootstrap engine, после чего ViewModel переводит UI в `stale`, `error` или отдельное feature-specific degraded состояние. Так presentation-компонент не начинает конкурирующий таймер и не создаёт второй запрос.

`BroadAppTemplate` реально использует `BroadLoadableView` для блока module list + bootstrap status card. Bootstrap health остаётся отдельной render-моделью: общий background timeout не превращает свежий module list в `stale`.

## Ручная приёмка без test target

Для каждого подключаемого feature вручную проверьте:

- `idle` не выглядит как бесконечная загрузка;
- initial loading показывает loader без ATT/review;
- refresh сохраняет content, scroll position и доступность касаний;
- `empty` не маскируется под error;
- `stale(error: nil)` всё равно показывает stale banner;
- `error(previousValue:)` не становится stale неявно;
- быстрый double tap запускает один retry благодаря ViewModel single-flight guard;
- backend-кнопка показывает spinner сразу после первого тапа, до первого `await`;
- длинная локализация, light/dark mode и Reduce Motion не ломают доступные
  fixture-сценарии;
- semantic accessibility и scalable layout проверяются по коду;
  отдельный прогон VoiceOver/Dynamic Type на устройствах не обязателен.
