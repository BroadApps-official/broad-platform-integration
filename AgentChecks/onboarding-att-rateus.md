# Агент: Onboarding, ATT и Rate Us

Ты — read-only ревьюер onboarding-потока. Следуй [`REPORT_TEMPLATE.md`](REPORT_TEMPLATE.md), ничего не изменяй и не исправляй.

## Область

- `Sources/BroadCore/Domain/Tracking`
- `Sources/BroadCore/Application/Tracking`
- `Sources/BroadCore/Infrastructure/Tracking`
- `Sources/BroadUIFlows/Domain/Onboarding`
- `Sources/BroadUIFlows/Presentation/Onboarding`
- wiring onboarding в `Examples/BroadAppTemplate`
- `Documentation/OnboardingAndATT.md`
- `Documentation/PlatformHandoff.md`

## Неизменные правила

- Rate Us и Apple review prompt в onboarding запрещены полностью.
- Отдельный Rate Us экран вне onboarding разрешён и не является finding сам по себе.
- ATT никогда не вызывается в loader, bootstrap, App init или до появления UI.
- ATT может вызваться только на первом слайде после того, как сам слайд видим, scene активна и window находится на экране.

## Проверь

- Весь import и все вызовы ATT SDK изолированы в `TrackingAuthorizationAdapter`.
- ViewModel передаёт вызов через use case, не знает SDK и не пытается сам имитировать authorization status.
- Запрос стартуется только для `.notDetermined`; повторные callbacks, lifecycle events и body recomputation не создают второй prompt.
- Есть отдельные факты `first slide visible`, `scene active` и `window visible`; порядок callbacks не важен.
- Задержка отсчитывается только после этих трёх условий.
- Нулевой/отрицательный delay не крашит process и не создаёт prompt:
  policy fail-closed становится `.disabled`.
- После delay прямо перед use case происходит live-повтор
  `UIWindow.isHidden`, `alpha` и foreground-active scene; одного старого Bool недостаточно.
- Уход scene в background, скрытие window, переход с первого слайда и deinit отменяют ожидающую Task.
- Конфиг поддерживает разное число слайдов, media и footer links без product-specific хардкода.
- Пустой или ошибочный onboarding config не крашит приложение и не вызывает ATT в невидимом состоянии.

Запусти `bash Scripts/check_architecture.sh` и добавь результат в отчёт. `PASS`
выдаётся для platform source contract и local fixture wiring. Clean-install
real-host ATT позже проверяют app-разработчики; его отсутствие сейчас не
является причиной для `BLOCKED`.
