# BroadApps iOS Platform

<p align="center">
  <a href="https://broadapps-ios-docs.nkhsnv.chatgpt.site" title="Открыть актуальную документацию BroadApps">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="Documentation/Assets/README/hero-dark.svg">
      <img alt="Самая актуальная документация — на сайте. broadapps-ios-docs.nkhsnv.chatgpt.site — открыть документацию" src="Documentation/Assets/README/hero-light.svg" width="100%">
    </picture>
  </a>
</p>

<h2 align="center">Самая актуальная документация — на сайте</h2>
<p align="center">
  <strong><a href="https://broadapps-ios-docs.nkhsnv.chatgpt.site">broadapps-ios-docs.nkhsnv.chatgpt.site →</a></strong><br>
  Подключение · правила приложения · примеры · проверка агентом<br><br>
  <a href="https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/app-standard"><strong>Применить стандарт</strong></a> ·
  <a href="https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/getting-started"><strong>Первое подключение</strong></a> ·
  <a href="https://broadapps-ios-docs.nkhsnv.chatgpt.site/search"><strong>Найти ответ</strong></a>
</p>

Здесь — необходимая информация для работы с integration repository:
модули, проверенные версии, запуск примера и команды проверки.
Подробные инструкции и актуальные правила читайте на сайте;
API конкретного выпуска сверяйте с README и DocC соответствующего тега модуля.

## Что подключать

Host app подключает **любой нужный модуль** напрямую через Swift Package Manager.
Обязательного `BroadPlatform` или другого umbrella package нет.
Этот repository хранит проверенный набор версий, общий пример и проверки;
**добавлять `broad-platform-integration` в зависимости приложения не нужно**.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="Documentation/Assets/README/platform-module-selection-dark.svg">
  <img alt="Приложение выбирает нужные products. UIFlows использует Monetization и Core; Extensions подключается независимо." src="Documentation/Assets/README/platform-module-selection-light.svg" width="100%">
</picture>

Проверенный набор **[4.0.0](https://github.com/BroadApps-official/broad-platform-integration/releases/tag/4.0.0)**:

| Product / repository | Для чего | Версия |
|---|---|---|
| [BroadExtensions](https://github.com/BroadApps-official/broad-extensions-ios) | Цвета, шрифты, клавиатура, swipe-back | [1.0.1](https://github.com/BroadApps-official/broad-extensions-ios/releases/tag/1.0.1) |
| [BroadCore](https://github.com/BroadApps-official/broad-core-ios) | Запуск, состояния, кеш, retry, логирование | [2.0.0](https://github.com/BroadApps-official/broad-core-ios/releases/tag/2.0.0) |
| [BroadMonetization](https://github.com/BroadApps-official/broad-monetization-ios) | Adapty, покупка, доступ, RU-оплата, токены | [4.0.0](https://github.com/BroadApps-official/broad-monetization-ios/releases/tag/4.0.0) |
| [BroadUIFlows](https://github.com/BroadApps-official/broad-ui-flows-ios) | Готовые onboarding, AppFlow и paywall | [4.0.0](https://github.com/BroadApps-official/broad-ui-flows-ios/releases/tag/4.0.0) |

Источник версий — [Compatibility/current.yml](Compatibility/current.yml).
[Обновление с набора 3.0.0](Documentation/UpdatingTo4.md): ограничения пакетов
меняются вместе; собственные exhaustive switches учитывают `.host` и `.rejected`.
UIFlows подтягивает Monetization и Core, Monetization — Core.
Если приложение напрямую импортирует нижележащий модуль, добавьте его product в target.
[Выбор модулей](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/module-selection) ·
[Совместимость и обновление](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/compatibility).

## Быстрое подключение

1. В Xcode откройте `File → Add Package Dependencies…` и добавьте URL нужного модуля, например `https://github.com/BroadApps-official/broad-core-ios.git`.
2. Для воспроизведения проверенного набора выберите **Exact Version** из таблицы и нужный product для app target. Сохраните `Package.resolved` в Git.
3. Настройте **iOS 17+, iPhone, Swift 5 language mode**. Для manifest с `swift-tools-version: 6.0` нужны инструменты SwiftPM 6.0; это не перевод исходников на Swift 6.
4. Соберите приложение в iPhone Simulator с **Team = None**.

Публичные модули скачиваются по HTTPS без GitHub account, password, token или API key.
Если Xcode просит пароль, проверьте старый URL `BroadApps-official/BroadCore`:
[диагностика подключения](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/public-package-access).

Дизайн, тексты, ключи SDK, placements, backend и авторизация принадлежат приложению.
[Готовый BroadStart и пошаговое подключение](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/getting-started).

## Нужна конкретная инструкция

| Задача | Статья на сайте |
|---|---|
| Применить общие компоненты и проверить приложение | [Стандарт приложения](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/app-standard) |
| Создать приложение вручную или с агентом | [Создание приложения](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/app-creation) |
| Перенести существующее приложение | [Переход со старого BroadCore](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/legacy-app-migration) |
| Настроить onboarding и ATT | [Первые экраны и разрешение Apple](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/onboarding-att) |
| Настроить placements, ключи, token/tokens и fallback | [Настройка Adapty](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/adapty-setup) |
| Подключить paywall, loader и защиту от повторного нажатия | [Paywall и состояния экрана](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/paywall-ui) |
| Подключить RU-оплату и подтверждение через account policy | [RU Billing](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/ru-billing) |
| Настроить A/B-тесты через Adapty | [RU Billing: эксперименты](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/ru-billing-ab-platform) |
| Подключить отдельные предложения | [Special Offer](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/special-offer) · [Токены](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/token-paywall) |
| Обработать ошибку, pending и восстановление аккаунта | [Запуск, ошибки и восстановление](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/runtime-reliability) |
| Исправить документацию или выпустить модуль | [Документация](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/documentation) · [Выпуск версии](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/release-process) |

## Запустить общий пример

`BroadAppTemplate` показывает совместную работу модулей: onboarding, paywall,
Special Offer, токены, RU flow и состояния ошибок. Это технический пример
с локальными сценариями, а не готовый дизайн приложения или настоящий платёж.
Три слайда в `BroadAppTemplate` — только демонстрационный пример; число страниц задаёт приложение.

```bash
git clone https://github.com/BroadApps-official/broad-platform-integration.git
cd broad-platform-integration
bash Scripts/install_build_tools.sh
bash Scripts/generate_example.sh
open Examples/BroadAppTemplate/BroadAppTemplate.xcodeproj
```

Выберите схему **BroadAppTemplate** и iPhone Simulator.
[Сценарии и параметры запуска](Examples/BroadAppTemplate/README.md) ·
[Как устроен пример и что проверять](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/app-standard#запустите-общий-пример).

## Проверить платформу или приложение

В Terminal из корня integration repository:

```bash
# Проверить окружение, затем платформу и четыре модуля
bash Scripts/agent_review_and_fix.sh platform --doctor
bash Scripts/agent_review_and_fix.sh platform

# Проверить конкретное приложение
bash Scripts/agent_review_and_fix.sh app "/path/to/MyApp" --scheme MyApp
```

Явные режимы выполняют аудит; `--fix` разрешает исправления.
Отчёт — проблема, файл, причина и необходимое исправление.
Открытый Codex/Claude использует [инструкцию reviewer](Documentation/AgentReview.md)
без рекурсивного запуска этого wrapper.

После изменения integration repository выполните обязательную проверку:

```bash
bash Scripts/agent_gate.sh
```

Она проверяет контракты, стиль, документацию и сборки Debug/Release
для iPhone Simulator и generic iOS без подписи. Для изменения отдельного
модуля используется его `bash Scripts/module_gate.sh`.
Юнит-тесты, XCTest, Swift Testing и новые test targets не добавляются.
Настоящие покупки и restore не выполняются; PASS платформы не заменяет QA приложения.

## Что хранится в этом repository

| Путь | Назначение |
|---|---|
| [Compatibility/current.yml](Compatibility/current.yml) | Точные совместимые версии и свидетельства проверки |
| [Examples/BroadAppTemplate](Examples/BroadAppTemplate) | Общий iPhone-пример |
| [Scripts](Scripts) | Сборки, контракты и запуск reviewer |
| [AgentChecks](AgentChecks) | Правила проверки платформы и приложения |
| [Documentation](Documentation/README.md) | Инженерные инструкции и шаблоны планов |
| [README.dev.md](README.dev.md) | Памятка по слоям и стилю кода |

[Изменения](CHANGELOG.md) · [Последняя проверка](AgentChecks/STATUS.md) ·
[Исходники сайта](https://github.com/BroadApps-official/broad-docs) ·
[Актуальная документация →](https://broadapps-ios-docs.nkhsnv.chatgpt.site)
