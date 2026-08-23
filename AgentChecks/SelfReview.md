# Developer self-review платформы и BroadAppTemplate

Дата: 2026-08-23. Scope — текущая платформа и интерактивный
`BroadAppTemplate`. Результат не распространяется автоматически на host apps.

## Результат

`PASS` для Simulator-first матрицы после layout-исправления и повторного аудита
Special Offer/analytics. Отсутствие платного аккаунта, Signing Team или
подписанной установки не является blocker-ом этого результата.

## Фактический прогон

| Проверка | Маленький iPhone | Большой iPhone | Результат |
|---|---|---|---|
| Main и каталог девяти сценариев | iOS 18.6 | iPhone 17 Pro, iOS 26.2 | PASS |
| Subscription/token/special/RU/loader/analytics/Contact Us/Debug | Пройдено | Пройдено | PASS по fixture-сценариям |
| Special Offer | Subscription → close → resolver → offer | Тот же flow | PASS без платежей |
| Общий recorder | События обеих презентаций и refresh | Тот же composition contract | PASS |
| Token paywall | Длинные подписи переносятся, каталог scrollable | Цена и текст видимы | PASS |
| Clean install | Первый onboarding-слайд показан до ATT | Каталог переустановлен | PASS |
| Background → foreground | Token paywall сохранился | Cold/relaunch проверены | PASS |
| Repeat/cold launch | Once/every/disabled | Once/every/disabled | PASS |

Полная функциональная матрица находится в
[`TemplateAcceptanceReport.md`](TemplateAcceptanceReport.md). Скриншоты прогона
лежат только в ignored `.build/Acceptance`.

## Найденный и исправленный layout-дефект

`BroadSelectableProductRow` ограничивал subtitle одной строкой и задавал
фиксированную высоту. После исправления title/subtitle переносятся по
содержимому, а колонка цены остаётся читаемой. Повторный визуальный прогон на
обоих размерах подтвердил результат.

## Повторный аудит Special Offer

Карточка раньше открывала offer напрямую и использовала отдельный невидимый
recorder. Теперь Simulator-прогон подтверждает
`subscription-paywall → resolver → special-offer`, новый presentation ID при
повторном входе и события обеих презентаций в общем recorder. Debug refresh
показывает видимое завершение.

## Осознанные границы

- Настоящие purchase, restore и RU checkout не запускались.
- Template — каталог возможностей платформы, а не дизайн отдельного app.
- App-owned backend, дизайн и configuration проходят отдельный checklist.
- Ручной запуск на iPhone возможен только доступным компании способом, вне
  platform gate и без изменения signing агентом.
