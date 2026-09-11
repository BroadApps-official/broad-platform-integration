# Обновление на набор 4.0.0

В Xcode → настройки проекта → Package Dependencies измените ограничения
уже подключённых пакетов вместе:

| Пакет | Exact Version |
|---|---|
| BroadCore | 2.0.0 |
| BroadMonetization | 4.0.0 |
| BroadUIFlows | 4.0.0 |
| BroadExtensions | 1.0.1 |

Подключать все четыре product не требуется. UIFlows использует Monetization
и Core, Monetization использует Core. Старые ограничения Core 1.x,
Monetization 3.x и UIFlows 3.x не допускают новый набор.

Выполните File → Packages → Resolve Package Versions. Проверьте фактические
версии в `Package.resolved` и сохраните его вместе с изменениями проекта.
Каталог набора: [Compatibility/current.yml](../Compatibility/current.yml).

## Изменения в приложении

- Если есть exhaustive `switch` по `BroadLogEvent`, обработайте новый `.host`.
  `BroadLogHostEvent` и `BroadLogHostField` принимают заранее объявленные
  `StaticString` для кодов, имён и текстовых значений; флаги — `Bool`,
  счётчики — `Int`. Произвольный runtime `String` не принимается.
- Если есть exhaustive `switch` по `TokenFulfillmentOutcome`, обработайте
  `.rejected`. Возвращайте его только при подтверждённом окончательном отказе
  backend. Временные сбои, timeout, ошибки авторизации и ожидание обработки
  сохраняют `.failed`, `.unavailable` либо `.pending`.
- `.failed` сохраняет recovery независимо от `AppError.isRetryable`.
  Уже начисленная тому же аккаунту покупка возвращает `.alreadyCredited`.
  Массово заменять `.failed` на `.rejected` нельзя: это потеряет recovery.
- UI API не менялся. Приложения без собственных switches по этим enum могут
  обойтись обновлением зависимостей.

## Проверка приложения

Соберите Debug/Release для iPhone Simulator и Release generic iOS без подписи.
На локальных fixtures проверьте покупку, временную ошибку начисления и Retry:
сохраняются evidence и attempt ID, покупка вызывается один раз, серверный
баланс применяется целиком. Отдельные сценарии — окончательный отказ,
`.alreadyCredited` и запись собственного log event.

Фактический backend и UI приложения проверяет его команда. Platform gate
покрывает общие контракты и пример; настоящие покупки/restore для него не нужны.

Для отката восстановите вместе проект, ограничения и lockfile из ветки
до обновления: Core 1.2.0, Monetization 3.0.0, UIFlows 3.0.0, Extensions 1.0.1.

[Подробная инструкция для команды](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/compatibility).
