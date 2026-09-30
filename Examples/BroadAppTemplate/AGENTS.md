# Инструкция агенту: аккаунт, backend-каталог и RU Billing

Этот файл действует для `BroadAppTemplate` и для нового host app, созданного из
него. Цель — сначала получить подтверждённый backend-контракт, а затем
подключить платформу без догадок и копирования значений другого приложения.

Для нового приложения с работающим backend в референсе следуй
`Documentation/AgentPreflight.md` и `Documentation/AppCreationWorkflow.md`
платформы. Читай референс без изменений, фиксируй commit SHA, сверяй запросы
с OpenAPI/проверками и согласуй расхождения с владельцем backend. На этапе
плана создай `Documentation/BackendContract.md`; неподтверждённое — `BLOCKED`
и конкретный вопрос. Переноси подтверждённое поведение через адаптеры платформы,
не старую архитектуру и хардкод; контент и продукты бери с backend/Adapty.
Чужие production URL, секреты, email, checkout URL, SKU и персональные данные
автоматически не копируй. Адрес нового приложения подтверждается отдельно.
`TEMPORARY` — только выбранные разработчиком данные Adapty, Debug-продуктов
и legal с источником и условием замены, не серверные секреты или production URL.

## Подписка в настройках

Покупки идут через Adapty/App Store, поэтому приложение не показывает
«Cancel subscription», не отменяет подписку и не открывает системный экран или
веб-страницу подписок App Store, даже если это есть в Figma. «Get Pro», статус
подписки и «Manage subscription» открывают пейвол приложения (обычно placement
`settings`) через `BroadSettingsHost(showPaywall:)` (BroadUIFlows после 6.5.0, через
общий tap gate). В 6.5.0 `manageSubscription()` ведёт в App Store — строки подписки
к нему не подключайте. Отмена подписки существует
только в RU Billing и идёт через backend.

## Обязательная декларация функций аккаунта

До реализации определите по задаче и `Documentation/AppIntegrationPlan.md`,
использует ли приложение расходуемые токены/баланс, серверный аккаунт и перенос
ID через iCloud. Заполните `Configuration/AccountIntegration.json`:

- `tokens`: `demo`, `backend` или `notUsed`;
- `accountRecovery`: `unconfigured`, `backend` или `notUsed`;
- `iCloudIdentity`: `undecided`, `enabled` или `disabled`.

Если баланса и токенов нет по требованиям, ставьте `tokens.mode = notUsed` и
запишите причину в `details`; не требуйте несуществующий token endpoint.
Отсутствие токенов не определяет наличие аккаунта: личные данные, RU-покупки и
другие серверные права проверяются отдельно. Для приложения без серверного
аккаунта допустимы `accountRecovery = notUsed` и `iCloudIdentity = disabled`;
восстановление Apple-подписки остаётся отдельным сценарием.

Не помечайте существующую fixture-функцию как `notUsed` ради тишины в сборке.
`backend` требует ссылки в `details` на фактический адаптер и проверку в плане;
`enabled`/`disabled` должны совпадать с Swift-настройкой. JSON описывает принятое
решение и сам не меняет UI, backend или Keychain. При неизвестных требованиях
оставьте предупреждение и запишите `BLOCKED` для соответствующей функции.

Сборка Xcode и platform gate запускают `Scripts/check_account_integration.rb`.
Не удаляйте build phase, декларацию или сообщения ради зелёного отчёта.
Не ослабляйте `SWIFT_TREAT_WARNINGS_AS_ERRORS`: предупреждения выдаёт отдельный
build phase. Подробности: `Documentation/AccountRecovery.md` платформы.

## Монетизация токенов

В Debug через `.storekit` покупаются все продукты Adapty с ценами App Store (подписки, спецоффер, consumable-токены из `tokens`): `LocalStoreKitPurchaseRepository` подключите к `PurchaseSelectedProductUseCase` и `TokenPurchaseManager`, каждый тип проверьте покупкой из Xcode с обновлением доступа/баланса; отказ backend сообщите с кодом ответа без локального зачисления; в Release — Adapty.

На временных данных `TEMPORARY` показывайте реальные цену и количество из Adapty/StoreKit и backend, а не примеры Figma. Название тарифа формирует приложение: менеджер пишет в имя продукта в App Store его ID, поэтому `plan.title`/`package.title` (имя из StoreKit) не показывайте. Подписка — по периоду («Yearly», «Monthly», «Weekly»), пакет — «N Tokens»: N из backend-каталога, а без него — ведущее число из product ID, только для надписи. На платформе — `plan.name` и `package.name` (UIFlows, Unreleased).

Нехватка токенов в любом действии и тап по балансу сразу открывают пейвол:
без подписки — подписочный (обычно `pro_icon`), с подпиской — `tokens` через
`BroadTokenPaywallHost`; алерт вместо пейвола запрещён. После покупки обновите
подтверждённый серверный баланс без автоповтора действия; если backend требует
подписку для токенов, отправляйте её после покупки, Restore и при запуске.

## Граница работы

- Не открывай и не изменяй платёжный кабинет: это не зона ответственности
  агента, который пишет app-side код.
- Не копируй production base URL, Bearer token, API key, email, checkout URL,
  SKU или персональные данные из другого приложения.
- Не выполняй покупку за реальные деньги, restore, RU checkout или cancellation.
- Не начинай Swift-изменения, пока backend-раздел
  `Documentation/AppIntegrationPlan.md` не заполнен и неизвестные значения не
  отмечены `BLOCKED`.

## Сначала собери входные данные

В host app, `AppIntegrationPlan.md` и переданном API-контракте найди и выпиши:

1. место, где собирается base URL;
2. endpoint, method, headers и auth для каталога;
3. request/response DTO без реальных значений секретов;
4. единицу `price` и валюту;
5. backend product ID и способ его точного сопоставления с Adapty/App Store;
6. request checkout и поле ответа с payment URL;
7. источник подтверждения подписки после браузера;
8. источник подтверждения token balance;
9. endpoint отмены и смысл `canceled`, `alreadyCanceled`, `willRenew`;
10. offline/timeout/empty policy и backend kill switch.
11. для account-policy — версия модуля и обработка завершения локального ожидания;
    если backend поддерживает отмену checkout, её контракт и terminal outcome.

Ищи не только название service. Проверяй фактические `URLRequest`/endpoint
builders, auth interceptor, DTO, composition root и место, где UI получает
результат.

## Что должно быть подтверждено

До кода должны быть известны catalog, checkout, status/policy и, если требуется,
cancel methods текущего приложения. Для account-policy с 5.0.0 серверная отмена
checkout опциональна. Если обязательные значения не записаны в плане, задай
разработчику/team lead один прямой вопрос:

> Передайте для текущего приложения catalog, checkout, status/policy и cancel
> methods, auth dependency, JSON schema, price units и точные product IDs.

## Наводящие вопросы, если ответа не хватает

Задавай только вопросы, которые меняют реализацию:

- `price` приходит в рублях или minor units/копейках?
- `productId` совпадает с Adapty/App Store ID символ в символ?
- Если ID различаются, где находится явное соответствие?
- Какие поля обязательны: `title`, `kind`, `period`, `credits`, `currency`?
- `paymentMethods` приходит для каждой строки или задаётся configuration?
- Email обязателен для checkout и откуда host app его получает?
- Какой endpoint является authority для Premium после возврата из браузера?
- Где читать подтверждённый token balance?
- Поддерживает ли backend отмену конкретного checkout? Для account-policy это
  опциональная возможность; её отсутствие не блокирует интеграцию с 5.0.0.
- Как UI ведёт себя при пустом каталоге, 401, timeout и частично битом JSON?
- Текущий app уже переведён на правило `Storefront RU OR iPhone region RU`?

Если backend owner не дал ответ, запиши точный blocker и продолжай только
независимые части. Не придумывай production contract.

## Правила реализации

- Каталог передаётся массивом 1:1: не `filter`, не `sorted`, не `compactMap`,
  не `prefix`, не dictionary и не deduplication.
- 0, 1, 2 и N строк — нормальные входы. Ограничить карточки может только
  app-owned UI после получения полного platform result.
- Не выводи `kind`, ID или соответствие по имени SKU, цене, периоду или позиции.
- Почти одинаковые IDs не считаются совпадением.
- Если точных совпадений нет или Adapty не вернул продукты, подключённый RU
  loader с 1.5.4 показывает все обычные подписки с `isDefault=true`.
  Без отметок сохраняется полный раздел подписок для старых каталогов.
  Исходный payload не сокращается; порядок, дубли и индексы выбранных строк
  сохраняются. Не подставляй defaults в отдельную несовпавшую Apple-карточку.
- Возврат/закрытие browser sheet не означает оплату. Premium открывается после
  подтверждения entitlement/policy; токены — после подтверждения balance.
- В account-policy с BroadMonetization 5.0.0 после `waitingCompleted` UI завершает
  ожидание и перечитывает operation gate для новой покупки. При `unavailable`
  показывай ошибку проверки, не отмену платежа; gate остаётся источником блокировки.
  Последняя попытка сохраняется для reconciliation, перед новым checkout нужна
  свежая policy. `checkoutTerminationClient` опционален; `pendingCheckoutTermination`
  вызывается только после подтверждения пользователя для реальной серверной отмены.
  Payment-status режим сохраняет pending до окончательного ответа.
- `ru_pay` отсутствует/false/invalid — RU Billing закрыт. Не подставляй true.
- Региональный gate: App Store Storefront `RU/RUS` **или** регион iPhone
  `RU/RUS`; язык, клавиатура, IP и timezone не участвуют.
- Production domain и auth остаются app-owned configuration/dependencies.

## Что показать перед изменениями

Для любого backend до app-кода покажи короткий отчёт по нужным функциям.
Для референсного backend добавь commit SHA, источник и статус подтверждения
каждого endpoint и расхождения с OpenAPI/владельцем backend:

```text
BACKEND CONTRACT GIVEN
- каждая функция: method/path, request/response, auth, ошибки/лимиты/retry/idempotency
- источник, статус подтверждения, компонент платформы
- для RU Billing: catalog (method/path/auth/response shape), checkout
  (method/path/body/response), confirmation (subscription authority + token
  authority), cancellation (subscription cancellation + pending-checkout
  termination) и расхождения с контрактом платформы

QUESTIONS
- только то, чего нет в источниках и что влияет на реализацию

BLOCKERS
- неподтверждённые endpoints и зависимые срезы с владельцем решения

PLAN
- app-owned configuration и platform adapters
- порядок срезов, UI states и безопасные проверки

НУЖНА ПРОВЕРКА КОНТРАКТА BACKEND
```

К реализации переходи после ответа разработчика. Детальный контракт:
[`../../Documentation/BackendProductCatalog.md`](../../Documentation/BackendProductCatalog.md).

## Если нужен спешл оффер RU Billing

Не добавляй отдельный campaign engine: экран, строгий gate и цикл 24/24
принадлежат обычному Adapty Special Offer. RU-ветка меняет только источник
продукта. Сначала верни разработчику этот список входных данных:

```text
RU SPECIAL OFFER GIVEN
- обычный paywall содержит strict bool special_offer = true
- отдельный Adapty placement special_offer настроен
- RU catalog: schema, price units, isSpecialOffer marker and exact IDs
- recurring/one-time mode, payment route, entitlement duration and legal copy
- checkout request and authoritative confirmation after browser return

QUESTIONS / BLOCKERS
- только неизвестные значения, меняющие реализацию

НУЖНА ПРОВЕРКА КОНТРАКТА RU SPECIAL OFFER
```

Правила:

- не открывай платёжный кабинет и не копируй значения другого приложения;
- RU-продукт выбирай только по строгому backend-маркеру `isSpecialOffer`
  (допустим согласованный snake_case alias); не выбирай по году, месяцу, цене,
  названию или позиции;
- обычный paywall исключает помеченную строку, а Special Offer не подставляет
  обычный тариф, если помеченной строки нет;
- если подтверждённый тип покупки и UI-текст противоречат друг другу, поставь
  `BLOCKED` и запроси team lead review;
- не смешивай `special_offer`, strict `ru_pay` и regional gate;
- используй фиксированные окно 24 часа и cooldown 24 часа общей реализации;
- возврат из Safari не является success: повторно проверь backend
  policy/entitlement;
- A/B-тесты RU Billing подключаются явно через tracker (с 1.4.0);
  используй Documentation/RUBillingExperiments.md. Резерв без ответа Adapty
  не создаёт вымышленные experiment/segment и отчёты;
- при неразрешённом gate, отсутствии помеченного продукта или пустом catalog
  ветка закрывается без настоящей оплаты.

Полная инструкция:
[`../../Documentation/RUSpecialOffer.md`](../../Documentation/RUSpecialOffer.md).

## Adapty unavailable → backend RU catalog (1.5.0)

Сохраняй существующие API и используй явно подключаемый
`LoadPaywallWithRUFallbackUseCase` / `makeServicesWithRUFallback`.
Нет ответа Adapty при RU Storefront или RU-регионе телефона разрешает запрос
свежего каталога приложения. Полученный `ru_pay=false`, invalid или отсутствующее
поле закрывает резерв. Не теряй запрет, если затем не загрузились StoreKit products.
С 1.5.3 успешный ответ продуктов `[]` также запускает этот резерв в той же
попытке. Достаточно одного российского региона; не требуй оба одновременно.
Не включай RU по языку, не подставляй true, не придумывай backend URLs/авторизацию.
Пример `ExampleRUProviderFallback` — локальный; настоящий checkout по-прежнему
требует согласованный backend-контракт и подтверждение доступа сервером.
