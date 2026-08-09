# Единое состояние загрузки данных

`LoadableState<Value>` — actor-neutral typed-модель из `BroadCore`. Она одинаково описывает первую загрузку, refresh уже показанных данных, пустой результат, допустимый offline fallback и блокирующую ошибку. Внутри нет SwiftUI, Combine, DI, `Task` или SDK-типов.

## Состояния

| Состояние | `value` | `error` | Семантика |
|---|---:|---:|---|
| `idle` | — | — | Запрос ещё не запускался или feature явно сброшена |
| `loading(previousValue: nil)` | — | — | Первая загрузка; контента пока нет |
| `loading(previousValue: value)` | ✓ | — | Идёт refresh, предыдущий контент остаётся на экране |
| `loaded(value)` | ✓ | — | Получен свежий подтверждённый контент |
| `empty` | — | — | Запрос успешен, но отображаемого контента нет |
| `stale(value, error: nil)` | ✓ | — | Feature разрешила использовать устаревший fallback |
| `stale(value, error: error)` | ✓ | ✓ | Fallback остаётся рабочим, refresh завершился неблокирующей ошибкой |
| `error(error, previousValue: nil)` | — | ✓ | Блокирующая ошибка без контента |
| `error(error, previousValue: value)` | ✓ | ✓ | Ошибка остаётся главной; старое значение сохранено только для контекста/retry |

Критическое различие: `stale` означает, что feature признала значение безопасным рабочим fallback. Наличие `previousValue` внутри `error` само по себе такого разрешения не даёт.

## Публичный API

```swift
var state: LoadableState<[Product]> = .idle

state = state.beginLoading()

if products.isEmpty {
    state = .empty
} else {
    state = .loaded(products)
}
```

Доступные безопасные свойства:

- `value` возвращает fresh, stale или сохранённое previous value;
- `error` возвращает typed `AppError` из `stale/error`;
- `isLoading` отличает выполняющийся запрос;
- `hasContent` сообщает, можно ли продолжать отображать контент;
- `beginLoading(preservingValue:)` начинает загрузку и по умолчанию сохраняет текущий value;
- `fail(with:preservingValue:)` создаёт блокирующее error-состояние и по умолчанию сохраняет текущий value.

`LoadableState` становится `Equatable` только когда `Value: Equatable`. Основной generic не требует `Equatable`, но всегда требует `Sendable`.

## Правила переходов

```text
idle                    → loading(previousValue: nil)
loaded(value)           → loading(previousValue: value)
stale(value, _)         → loading(previousValue: value)
error(_, previousValue) → loading(previousValue: previousValue)
empty                   → loading(previousValue: nil)

loading → loaded | empty | stale | error
loaded  → stale
stale   → stale | loaded
any settled state → idle   // только явный reset владельца
```

При ошибке после refresh решение принимает feature:

```swift
let previousState = state
let fallback = state.value
state = state.beginLoading()

do {
    let value = try await loadValue()
    state = .loaded(value)
} catch is CancellationError {
    state = previousState
} catch {
    let appError = errorMapper.map(error)

    if let fallback, featurePolicy.canUseAsFallback(fallback) {
        state = .stale(value: fallback, error: appError)
    } else {
        state = state.fail(with: appError)
    }
}
```

Raw SDK/backend error сначала преобразуется в безопасный `AppError`; напрямую класть его в state нельзя.

## Empty и Optional

`Value` должен быть семантически non-optional. Не используйте `LoadableState<Product?>`: `.loaded(nil)` начинает дублировать `.empty`. Если `nil` имеет отдельный доменный смысл, оберните его в именованный доменный enum.

Для коллекций успешный пустой ответ выражается `.empty`, а не `.loaded([])`. Общая модель намеренно не угадывает пустоту автоматически: только feature знает, является ли пустая коллекция валидным empty-screen или ошибкой конфигурации.

## Cancellation и устаревшие ответы

`CancellationError` — control flow, а не `.error`. Если при отмене нужно точно восстановить состояние, сохраните весь previous `LoadableState`, а не только `value`: одно значение не сообщает, было оно `loaded` или `stale`.

Модель не защищает от позднего async-ответа сама. ViewModel/use case должны использовать cancellation, generation или load ID, чтобы старый запрос не перезаписал результат более нового.

## Границы ответственности

- `AppBootstrapState` описывает внутренний lifecycle bootstrap engine. Он не заменён на `LoadableState`.
- `CacheReadResult` сообщает физическую freshness записи в storage.
- `LoadableState` сообщает, что конкретная feature/ViewModel решила показывать пользователю.
- Repository возвращает доменный результат; ViewModel/Application-слой преобразует его в `LoadableState` по feature policy.
- Swinject-регистрация не нужна: это value model, а не сервис.

## Реальный example

`BroadAppTemplate` хранит список модулей как `LoadableState<[ModuleItem]>`:

```text
AppBootstrapState.idle           → moduleState.idle
AppBootstrapState.starting       → moduleState.loading(previousValue: modules?)
AppBootstrapState.ready          → moduleState.loaded(modules)
AppBootstrapState.degraded       → moduleState.loaded(modules) + degraded status card
AppBootstrapState.failed(error)  → moduleState.error(error, previousValue: modules?)
```

`RootView` передаёт `moduleState` в `BroadLoadableView` и строит module list из associated value конкретного состояния. Refresh остаётся в одной structural content-ветке и не создаёт мерцание. Для безопасного module list example явно показывает previous modules в `failure` builder; renderer не делает это автоматически. Отдельная render-модель оставляет bootstrap health, тексты, иконки и цвета внутри Presentation. Готовые UI-компоненты и таблица рендеринга: [Loadable UI](LoadableUI.md).

Общий `AppBootstrapState.degraded` намеренно не превращается в `stale`: причиной может быть background SDK timeout, который не делает module content устаревшим. `stale` создаётся только там, где конкретная feature получила typed cached value и явно разрешила fallback.

Новые test targets не добавлены. Существующие launch fixtures дают ручные сценарии `idle/loading/loaded`, degraded health с `loaded` content и `error → loading → loaded`. Искусственные `stale/empty` сценарии не создаются до появления настоящего cached/empty каталога или feature.
