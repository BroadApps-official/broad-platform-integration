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

Метка Kaiten «Жду аккаунт» — нет ключа Adapty, продуктов, PP/ToU. Спроси разработчика,
какое похожее приложение компании взять за образец (где есть те же экраны, например
токены), — не выбирай сам. Временно возьми его данные:

- ключ Adapty и плейсменты — в `Configuration/*.xcconfig` → `Info.plist`;
- продукты — его `Debug.storekit` в схему по правилу «Проверка `.storekit`» ниже;
- SKU подписок для проверки доступа и ссылки PP/ToU — в одном месте кода;
- у каждого значения комментарий `TEMPORARY: <номер приложения>` и пункт в плане.

Перед выпуском заменяются данными из Kaiten.

## Как проверять покупки

TestFlight и доступа к кабинетам Adapty и App Store Connect у разработчиков нет — всё у
аккаунт-менеджеров. Покупку за реальные деньги не проверить; изменения плейсментов, продуктов и
Remote Config разработчик просит у аккаунт-менеджера.

Debug: Adapty + локальный `.storekit`. Каждый путь покупки использует
`LocalStoreKitPurchaseRepository`: подписки основных пейволов и спецоффера через
`PurchaseSelectedProductUseCase`, пакеты токенов через `TokenPurchaseManager`.
В Release покупка идёт через Adapty. Проверь оба пути: частая ошибка — локальный
StoreKit подключён к подпискам, а токены остались без него или без токен-пейвола.
`.storekit` применяется только при запуске из Xcode (Run), не через `simctl`:
тарифов нет, купить нельзя. Для проверки пейвола и покупок
запускай приложение сам, не проси разработчика:

```bash
osascript -e 'tell application "Xcode"' -e 'set ws to active workspace document' -e 'set active run destination of ws to (first run destination of ws whose name is "<simulator>")' -e 'run ws' -e 'end tell'
```

Если разработчик уже запустил приложение из Xcode, не нажимай в его сессии.
Сборка без подписи ломает Keychain-ID. Лист покупки StoreKit в Debug — тестовый,
деньги не списываются. Покупки за реальные деньги и restore не выполняй. Срез с покупками
не готов, пока ты сам не купил в Debug каждый тип продукта: лист оплаты появился,
покупка прошла, доступ или подтверждённый баланс обновился. Если backend отклонил
тестовую транзакцию из `.storekit` (например, HTTP 422), покажи разработчику код
ответа и что требуется от backend; не имитируй локальное зачисление.

При проверке токенов пройди генерацию, повтор, шаблон и «ещё раз»: нехватка
токенов сразу открывает подписочный пейвол без подписки или `tokens` с подпиской,
не алерт. Тап по балансу ведёт туда же. После покупки обновляется подтверждённый
серверный баланс, действие не повторяется автоматически. Если backend требует
подписку для токенов, проверь её синхронизацию после покупки, Restore и при запуске.

### Проверка `.storekit`

В `.storekit` должны быть все продаваемые приложением продукты плейсментов Adapty
с ценами App Store: подписки основных пейволов, продукт `special_offer` и
consumable-пакеты токенов, включая placement `tokens`. Adapty отдаёт только те
продукты, которые есть в файле: не хватает продукта — пейвол молча показывает
меньше товаров. После каждой смены продуктов или плейсментов:

```bash
ruby ~/.claude/skills/broadapps-new-app/scripts/check_debug_storekit.rb . --expect id1,id2
```

(для Codex — `~/.codex/skills/...`). Скрипт проверяет, что ссылка в схеме ведёт на
файл из проекта (не красная), что файл не копируется в приложение, и печатает продукты
с ценами. ID для `--expect` — у аккаунт-менеджера, в образце или в предупреждении DEBUG
платформы `missing vendor product IDs`. Цены — как в App Store.

## Экраны

Экран = только вёрстка поверх хостов BroadUIFlows (`BroadOnboardingFlowHost`,
`BroadPaywallHost`, `BroadTokenPaywallHost`, `BroadSettingsHost`). Спецификации и
картинки из Figma — скилл `broadapps-figma`, проверка устройств — `broadapps-ipad-check`.
