# Debug-настройки и мгновенный отклик backend-кнопок

Здесь описаны две небольшие вещи, которые сильно упрощают ежедневную
разработку:

1. безопасная очистка Keychain из Debug-настроек;
2. ромашка на кнопке сразу после запуска долгого действия.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="Assets/README/debug-feedback-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="Assets/README/debug-feedback-light.svg">
  <img alt="Очистка app-owned Keychain в Debug и мгновенный loader backend-действия" src="Assets/README/debug-feedback-light.svg" width="100%">
</picture>

## Очистка Keychain во время разработки

Keychain переживает удаление и повторную установку приложения. Поэтому во
время разработки старый token или идентификатор может неожиданно влиять на
новый запуск. Для такого случая `BroadAppTemplate` содержит
готовый пример `DebugKeychainCleaner`, который копируется в host-приложение
вместе с Debug-настройками.

> [!IMPORTANT]
> Cleaner существует только под `#if DEBUG`. Он удаляет только
> `kSecClassGenericPassword` с точным `service`, который приложение передало
> само. Команды «очистить весь Keychain устройства» в платформе нет.

### 1. Перечислите app-owned сервисы в конфигурации

Используйте те же `service`, с которыми ваш Keychain-adapter сохраняет
session, token или development identity:

```swift
enum AppConfiguration {
    #if DEBUG
    static let debugKeychainScopes = [
        DebugKeychainScope(service: "com.company.app.credentials"),
        DebugKeychainScope(service: "com.company.app.session")
    ]
    #endif
}
```

Если приложение использует Keychain Sharing, передайте точный
`accessGroup`. Не добавляйте чужие service/access group и не используйте
пустой scope.

### 2. Создайте cleaner в composition root

```swift
#if DEBUG
let debugKeychainCleaner = DebugKeychainCleaner(
    scopes: AppConfiguration.debugKeychainScopes,
    failureError: AppError(
        kind: .unavailable,
        userMessage: "Не удалось очистить данные разработки.",
        diagnosticCode: "debug.keychain.cleanup-failed",
        isRetryable: true
    )
)
#endif
```

### 3. Покажите кнопку только в Debug-настройках

Путь должен быть очевидным:

```text
Настройки → Debug-настройки → Очистить Keychain → Подтвердить
```

До удаления покажите confirmation. Во время удаления покажите spinner. После
успеха попросите разработчика перезапустить сценарий и войти заново.

Кнопка не должна:

- появляться в Release;
- запускаться при старте приложения;
- удалять `UserDefaults`, кеш и файлы без отдельного действия;
- очищать Apple/RU/token pending-записи — это защита от двойного списания;
- скрывать ошибку удаления.

Готовый пример находится в `BroadAppTemplate`: значок инструментов на основном
экране открывает `Debug-настройки`.

## Ромашка сразу после нажатия

Если пользователь нажал «Сгенерировать», «Найти», «Отправить» или другую
кнопку с backend-запросом, интерфейс должен отреагировать сразу. Нельзя ждать
ответа backend и только потом менять экран.

Правильный порядок:

```text
тап → isInFlight = true → spinner и блокировка кнопки → await use case
    → success: следующий экран
    → error: убрать spinner и показать понятный Retry
```

`BroadActionButton` уже показывает `ProgressView`, когда получает
`isInFlight: true`. Состоянием владеет ViewModel.

### ViewModel

```swift
@MainActor
final class GeneratorViewModel: ObservableObject {
    @Published private(set) var isGenerating = false

    private let generate: any GenerateUseCaseProtocol
    private var generationTask: Task<Void, Never>?

    func generateTapped() {
        guard generationTask == nil else { return }

        // Важно: меняем UI до создания и ожидания backend-задачи.
        isGenerating = true

        generationTask = Task { @MainActor [weak self, generate] in
            let result = await generate()
            guard let self, !Task.isCancelled else { return }

            generationTask = nil
            isGenerating = false
            apply(result)
        }
    }
}
```

### View

```swift
BroadActionButton(
    configuration: BroadActionConfiguration(
        title: "Сгенерировать",
        inFlightTitle: "Запускаем генерацию…",
        isInFlight: viewModel.isGenerating,
        action: viewModel.generateTapped
    ),
    tint: AppTokens.Color.accent,
    theme: appLoadableTheme
)
```

Такой маленький spinner нужен даже тогда, когда после ответа приложение
переходит на отдельный экран загрузки. Он закрывает промежуток между тапом и
переходом и показывает, что команда принята.

## Как проверить

- [ ] Spinner появляется сразу после первого тапа, а не после ответа backend.
- [ ] Пока `isInFlight == true`, повторный тап не создаёт второй запрос.
- [ ] Кнопка не исчезает и не выглядит зависшей до смены route.
- [ ] Success переводит на ожидаемый экран.
- [ ] Offline/timeout/error убирают spinner и показывают понятное действие.
- [ ] Уход с экрана корректно отменяет UI-task либо оставляет серверную операцию
      в согласованном pending/history-сценарии.
- [ ] Кнопка очистки Keychain есть только в Debug.
- [ ] Cleaner получает только app-owned service/access group.
- [ ] После очистки показан результат, и можно заново пройти login/первый запуск.

Связанные инструкции: [Loadable UI](LoadableUI.md),
[Loadable State](LoadableState.md), [Network Interruptions](NetworkInterruptions.md)
и [Security](Security.md).
