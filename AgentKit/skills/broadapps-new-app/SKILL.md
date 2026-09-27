---
name: broadapps-new-app
description: Start or continue a BroadApps iPhone app on the BroadApps iOS Platform — staged workflow with developer stops, temporary account data while the account is pending, Figma or no-code. Use when a developer asks to build a company app or gives the platform site link.
---

# Новое приложение на платформе BroadApps

Вход для агента: https://broadapps-ios-docs.nkhsnv.chatgpt.site/llms.txt — прочитай его
первым. Там маршрут, правила и ссылки на промпты этапов.

## Этапы

Каждый этап заканчивается фразой остановки и одной строкой «что проверить»:

0. Проверка источников: Kaiten, Figma или no-code, backend, версии платформы — отчёт
   READY/BLOCKED.
1. План `Documentation/AppIntegrationPlan.md` по шаблону платформы, без Swift —
   «НУЖНА ПРОВЕРКА ПЛАНА».
2. Каркас: проект, модули точного набора из `Compatibility/current.yml`, дизайн-система
   по кадрам Figma, composition root, алерт обновления — «НУЖНА ПРОВЕРКА КАРКАСА».
3. По одному разделу: спроси, с какого начать (онбординг и пейвол, основная часть,
   настройки), и попроси ссылки на кадры Figma этого раздела — «НУЖНА ПРОВЕРКА ФУНКЦИИ».
4. Поведение, 5. Внешний вид (с проверкой iPad и iPhone SE), 6. Передача.

## Аккаунта ещё нет

Метка Kaiten «Жду аккаунт» — нет ключа Adapty, продуктов, PP/ToU. С разрешения
разработчика временно возьми их у похожего приложения компании (где есть те же экраны,
например токены):

- ключ Adapty и плейсменты — в `Configuration/*.xcconfig` → `Info.plist`;
- продукты — его `Debug.storekit` в схему;
- SKU подписок для проверки доступа и ссылки PP/ToU — в одном месте кода;
- у каждого значения комментарий `TEMPORARY: <номер приложения>` и пункт в плане.

Перед выпуском заменяются данными из Kaiten.

## Как проверять покупки

TestFlight и доступа к кабинетам Adapty и App Store Connect у разработчиков нет — всё у
аккаунт-менеджеров. Настоящую покупку не проверить; изменения плейсментов, продуктов и
Remote Config разработчик просит у аккаунт-менеджера.

Debug: Adapty + локальный `.storekit`. Он применяется только при запуске из Xcode (Run),
не через `simctl`; сборка без подписи ломает Keychain-ID. Лист покупки StoreKit в
Debug — тестовый, деньги не списываются. Настоящие purchase/restore не выполняй.

## Экраны

Экран = только вёрстка поверх хостов BroadUIFlows (`BroadOnboardingFlowHost`,
`BroadPaywallHost`, `BroadTokenPaywallHost`, `BroadSettingsHost`). Спецификации и
картинки из Figma — скилл `broadapps-figma`, проверка устройств — `broadapps-ipad-check`.
