# Developer self-review платформы и BroadAppTemplate

Дата: 2026-08-23. Scope — текущая платформа и интерактивный
`BroadAppTemplate`. Результат не распространяется на ещё не созданное
приложение 5135 Seedance.

## Результат

`PASS` для доступных Simulator-проверок после одного исправления layout.
Проверка системного Mail composer, VoiceOver и Dynamic Type на физическом
iPhone остаётся `BLOCKED` до выбора signing team и описана отдельно в
[`PhysicalDeviceReport.md`](PhysicalDeviceReport.md).

## Фактический прогон

| Проверка | Маленький iPhone | Большой iPhone | Результат |
|---|---|---|---|
| Main и каталог девяти сценариев | iOS 18.6 | iPhone 17 Pro, iOS 26.2 | PASS |
| Subscription/token/special/RU/loader/analytics/Contact Us/Debug | Пройдено | Пройдено | PASS по безопасным fixture-сценариям |
| Token paywall после layout-исправления | Длинные подписи переносятся; остальные пакеты доступны прокруткой | Длинные подписи переносятся; цена остаётся видимой | PASS |
| Clean install | Первый onboarding-слайд фактически показан до ATT; системный диалог отвечает | Ранее проверена чистая установка каталога | PASS в Simulator |
| Background → foreground | Token paywall сохранился без сброса и падения | Основные cold/relaunch-сценарии проверены при acceptance | PASS |
| Repeat/cold launch | Once/every/disabled проверены отдельно | Once/every/disabled проверены отдельно | PASS |
| Светлая/тёмная системная тема | UI остаётся в собственной тёмной palette | UI остаётся в собственной тёмной palette | N/A для переключения темы: template намеренно использует фиксированные app tokens |

Полная функциональная матрица находится в
[`TemplateAcceptanceReport.md`](TemplateAcceptanceReport.md). Скриншоты прогона
лежат только в ignored `.build/Acceptance` и не являются production assets.

## Найденный и исправленный дефект

`BroadSelectableProductRow` ограничивал subtitle одной строкой и одновременно
задавал всей карточке фиксированную высоту. Поэтому текст пакета `500 токенов`
обрезался многоточием даже на большом iPhone.

Исправлено:

- фиксированная высота заменена минимальной;
- title и subtitle получают вертикальный размер по фактическому содержимому;
- правая колонка цены остаётся однострочной и не перекрывается текстом.

Повторный визуальный прогон на обоих размерах подтвердил полный перенос строки.

## Осознанные границы

- Настоящие purchase, restore и RU checkout не запускались.
- Template — каталог платформы, а не visual reference приложения 5135.
- Физический iPhone подключён, но установка не выполнялась без выбранной
  владельцем signing team.
- Переключение system appearance не меняет fixed dark palette template; это не
  выдаётся за проверку двух поддерживаемых тем.
