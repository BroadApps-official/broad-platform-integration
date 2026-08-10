# BroadExtensions

`BroadExtensions` — маленький независимый package product с повторяющимися
iOS-утилитами. Он не зависит от `BroadCore`, `BroadMonetization` или
`BroadUIFlows`.

Подключайте продукт только тем target, где он реально нужен:

```swift
import BroadExtensions
```

## Hex → Color

Поддерживаются `RGB`, `RGBA`, `RRGGBB` и `RRGGBBAA`, с `#` или без него.
Некорректная строка возвращает `nil`.

```swift
let accent = Color(broadHex: "#4F8CFF")
let overlay = UIColor(broadHex: "101828CC")
```

## Кастомные шрифты

Сначала один раз зарегистрируйте файлы из bundle, затем создавайте SwiftUI или
UIKit font. SwiftUI-вариант поддерживает Dynamic Type scaling через
`relativeTo`, UIKit — через `UIFontMetrics`.

```swift
try BroadFontRegistrar.register(
    resourceNames: ["Inter-Regular", "Inter-Bold"],
    withExtension: "ttf",
    in: .main
)

let title = Font.broadCustom("Inter-Bold", size: 28, relativeTo: .title)
let body = UIFont.broadCustom("Inter-Regular", size: 16)
```

## Закрыть клавиатуру тапом снаружи

```swift
Form {
    TextField("Email", text: $email)
}
.broadDismissKeyboardOnTap()
```

Модификатор использует simultaneous gesture, поэтому не забирает обычные tap
действия у дочерних элементов.

## Вернуть системный swipe-back

```swift
DetailView()
    .navigationBarBackButtonHidden(true)
    .broadInteractiveSwipeBack()
```

Bridge действует только на текущий navigation controller, сохраняет прежний
gesture delegate и восстанавливает его при закрытии экрана. Глобального
swizzling нет.

## Что намеренно не добавлено

- глобальные `String`, `View` или `UIApplication` extension без префикса;
- force unwrap и silently-failing font registration;
- собственный navigation stack;
- универсальный «мешок helpers» без понятного владельца;
- extension из одного проекта, если он не повторяется в приложениях.

Так `BroadExtensions` остаётся небольшим и не превращается в скрытую
зависимость всей платформы.
