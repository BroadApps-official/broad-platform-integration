# App Integration Plan

> Если в repository конкретного приложения ещё нет
> `Documentation/AppIntegrationPlan.md`, скопируйте этот файл. Существующий
> Plan не перезаписывайте: сохраните его значения и добавьте только
> отсутствующие поля с developer review. Не добавляйте credentials или
> персональные данные.

## 0. Контекст

| Поле | Значение |
|---|---|
| Режим | `new app` / `existing app` |
| Host repository |  |
| App target / workspace |  |
| Platform repository | `https://github.com/BroadApps-official/broad-platform-integration` |
| Platform documentation commit |  |
| Compatibility `platform_set` |  |
| Legacy source / package reference |  |
| Текущий stage |  |
| Последний подтверждённый checkpoint |  |
| Ссылка на source requirements |  |

Для `existing app` сначала перечислите current behavior и gaps. Не создавайте
второй target и не переписывайте подтверждённые части до review плана.
`Platform documentation commit` — фактически прочитанный SHA canonical public
integration repository. Private `BroadApps-official/BroadCore`, local package
или copied sources записываются только как legacy evidence, а не как источник
новых module versions.

## 1. Статус входов

| Вход | Источник | Статус `READY/BLOCKED/N/A` | Владелец blocker-а |
|---|---|---|---|
| Platform workflow + compatibility |  |  |  |
| Kaiten / требования |  |  |  |
| Design source |  |  |  |
| Reference read-only |  |  |  |
| Backend contracts |  |  |  |
| Monetization decisions |  |  |  |
| Support/legal |  |  |  |

## 2. Cutover topology

Для `new app` укажите `N/A`. Для `existing app` заполните по фактическим
package manifests, Xcode references, target membership и imports.

| Поле | Значение / evidence |
|---|---|
| `Cutover topology` | `atomic package cutover` / `independent package boundaries` / `copied-source boundary` / `wrapper boundary` / `mixed` / `N/A` |
| `Legacy owner` | package identity/URL/ref, local path, copied target membership или implementation за wrapper |
| `Conflicting targets` | target/module names; если конфликтов нет — доказательство из final graph |
| Final graph invariant | ровно один source owner на каждый target name |

### Cutover groups

| ID | `Atomic cutover group` — что меняется вместе | Public repositories / products / exact versions | Compile-only adaptations | Resolve point | Rollback | Статус |
|---|---|---|---|---|---|---|
|  |  |  |  | только final graph |  |  |

Для `independent package boundaries` каждая boundary получает отдельную group.
Для `atomic package cutover` одна group может включать несколько public
repositories/products, но только реально используемые и их обязательные
transitive dependencies. Не запускайте resolve внутри неполной group.

## 3. Ownership

| Область | Platform component | Что делает агент | App-owned решение/код | Кто подтверждает |
|---|---|---|---|---|
| AppFlow |  |  |  |  |
| Premium entitlement |  |  |  |  |
| Subscription paywall |  |  |  |  |
| Token flow |  |  |  |  |
| Special Offer |  |  |  |  |
| Backend features |  |  |  |  |
| Analytics |  |  |  |  |
| Support |  |  |  |  |

## 4. Карта экранов и состояний

| Экран/состояние | Source frame | Entry point | Data/use case | Статус |
|---|---|---|---|---|
| Launch/loading |  |  |  |  |
| Onboarding |  |  |  |  |
| Main |  |  |  |  |
| Settings |  |  |  |  |
| Subscription paywall |  |  |  |  |
| Token paywall |  |  |  |  |
| Special Offer |  |  |  |  |
| Empty/error/offline |  |  |  |  |
| Contact Us |  |  |  |  |

## 5. Backend и hooks

| Функция | Method/endpoint или SDK | Request/response schema | Обязательные поля | Auth | Retry/offline | Server-owned hook/result | Статус |
|---|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |  |

`READY` ставится только после contract smoke по согласованной schema или
обезличенному production-shape fixture. Локальная заглушка, кнопка или успешная
компиляция не доказывают backend.

### Подтверждённый backend-контракт RU Billing

Не вставляйте секреты или полный production URL. Запишите только значения,
которые переданы для текущего приложения.

| Контракт | Переданное значение | Решение для текущего app | Статус |
|---|---|---|---|
| `GET /v1/tokens/products` или другой catalog path | Method/path/auth/envelope/fields |  |  |
| `POST /v1/billing/cloudpayments/checkout` или аналог | Body + payment URL/status fields |  |  |
| `GET /v1/policy/effective` или другой entitlement authority | Какие поля подтверждают Premium |  |  |
| Backend balance/wallet | Как подтверждаются купленные токены |  |  |
| `POST /v1/billing/cloudpayments/cancel` или аналог | Response и смысл renewal fields |  |  |
| Неизвестные значения | Вопрос тимлиду/backend owner; не угадывать |  |  |

Endpoint/schema/auth подтверждает владелец текущего backend. Инструкция агенту
и список наводящих вопросов:
`Examples/BroadAppTemplate/AGENTS.md`.

## 6. Монетизация

| Решение | Выбранный вариант | Источник | Статус |
|---|---|---|---|
| Initial paywall | once / every cold launch / disabled |  |  |
| Premium authority |  |  |  |
| Tokens | enabled / disabled + fulfillment endpoint |  |  |
| Special Offer | enabled / disabled + placement/gate |  |  |
| RU Billing | enabled / disabled + backend/legal |  |  |
| RU Special Offer | enabled / disabled + campaign/coupon/timers |  |  |
| RU product catalog | endpoint/schema/price units + exact mapping |  |  |
| Recovery | Apple/backend + account token balance endpoint; processed purchase IDs остаются backend-internal |  |  |

### RU Billing: заполнить, если feature не `N/A`

| Вопрос | Решение / evidence | Статус |
|---|---|---|
| Host composition и backend/legal подключены? |  |  |
| Какое production-значение `ru_pay`? | `true` / `false`; владелец флага |  |
| Как доказывается freshness? | Endpoint/schema/TTL/offline policy; `.verifiedFreshRemote` только после network response |  |
| Как проверяется российский пользователь? | App Store Storefront `RU/RUS` **или** регион iPhone `RU/RUS`; язык не участвует |  |
| Текущий app уже использует это правило? | Сверить реализацию с актуальной платформой и подтвердить у team lead |  |
| Как загружается каталог? | Endpoint, HTTP method, auth, envelope, error/offline policy |  |
| Совпадают ли backend и Adapty/App Store IDs? | Exact equality или явная mapping table/decoder; не угадывать |  |
| Какая единица `price`? | основные единицы валюты / minor units; не угадывать |  |
| Как сопоставляются продукты? | точный backend ID ↔ App Store product ID; без поиска по цене/периоду |  |
| Какие payment methods поддержаны? | `sbp` / `card`; подтвердить с backend/legal |  |
| Где backend kill switch? | Endpoint/policy и владелец |  |
| Debug override подключён? | `Как в Adapty` / force-on / force-off; только Debug |  |
| Какой live smoke пройден? | Verified `true/false`; provider/platform cache rejection; без purchase |  |
| Чем подтверждается результат после browser return? | Premium: policy/entitlement; tokens: backend balance; закрытие браузера не success |  |

### Спешл оффер RU Billing: заполнить, если feature не `N/A`

| Вопрос | Решение / evidence | Статус |
|---|---|---|
| Какой gate разрешает второй экран? | strict boolean `special_offer = true` в Remote Config обычного paywall |  |
| Какой отдельный placement содержит продукты? | `special_offer` либо точное имя от аккаунт-менеджера |  |
| Покупка recurring или one-time? | подтверждённый backend contract + legal copy должны совпадать |  |
| Какой payment route фактически production? | переданная backend-конфигурация текущего приложения |  |
| Кто и на какой срок выдаёт/продлевает entitlement? | authority + duration + renewal/cancellation semantics |  |
| Откуда приходит RU-продукт? | backend catalog со строгим `isSpecialOffer` marker |  |
| Как выбирается продукт? | только marked row; без выбора по цене, названию, периоду или позиции |  |
| Откуда приходит Apple-вариант? | placement + exact product ID + правило совместимости периода |  |
| Как хранится cycle? | persisted window 24 часа + cooldown 24 часа по trusted clock |  |
| Каков countdown? | до конца окна; на нуле экран закрывается и начинается cooldown |  |
| Какие gate разрешают RU method? | verified-fresh `ru_pay = true` + Storefront RU **или** регион iPhone RU + точный catalog product |  |
| Что отправляется в checkout? | exact resolved RU product ID + обязательные поля текущего backend |  |
| Что подтверждает success? | authoritative policy/entitlement после browser return; не сам возврат |  |
| Что происходит при pending/timeout? | повтор проверки без автоматического второго checkout |  |

Окно, countdown и cooldown образуют один фиксированный контракт 24/24. RU
Special Offer не добавляет поверх него app-owned eligibility. Backend products
сохраняются полным списком; Special Offer использует только строки с точным
backend-маркером.

[Полный контракт →](../RUSpecialOffer.md)

Release не может иметь app-default или force override для `ru_pay`.
Fixture/Debug force-on не считается evidence freshness, backend или успешной оплаты.
Отсутствующий/`false`/некорректный `ru_pay`, пустой каталог и два non-RU
региональных сигнала должны оставлять только Apple. Миграция блокируется, если
старый app включает RU Billing по языку или молча подставляет `ru_pay = true`.

## 7. Runtime slices after cutover

| Cutover group | Порядок после cutover | Runtime slice | Вход → итог | Зависимости | Статус | Developer review |
|---|---:|---|---|---|---|---|
|  | 1 |  |  |  |  |  |

Runtime slice начинается только после принятого dependency switch своей group.
Каждый срез проходит `View → ViewModel → use case → repository → client` и
заканчивается `MIGRATION SLICE REVIEW REQUIRED` для migration или
`SLICE REVIEW REQUIRED` для new app до начала следующего.

## 8. Blockers

| Функция | Чего нет | Где проверено | Владелец | Что можно продолжить независимо |
|---|---|---|---|---|
|  |  |  |  |  |

## 9. Checkpoints

| Checkpoint | Статус | Кто подтвердил | Evidence |
|---|---|---|---|
| `PLAN REVIEW REQUIRED` |  |  |  |
| `SKELETON REVIEW REQUIRED` |  |  |  |
| `FUNCTIONAL REVIEW REQUIRED` |  |  |  |
| `VISUAL REVIEW REQUIRED` |  |  |  |
| `READY FOR QA` |  |  |  |

Для legacy migration дополнительно заполните:

| Checkpoint | Статус | Кто подтвердил | Evidence |
|---|---|---|---|
| `MIGRATION PREFLIGHT REVIEW REQUIRED` |  |  |  |
| `MIGRATION PLAN REVIEW REQUIRED` |  |  |  |
| `DEPENDENCY SWITCH REVIEW REQUIRED` |  |  |  |
| `MIGRATION SLICE REVIEW REQUIRED` |  |  |  |
| `LEGACY CLEANUP REVIEW REQUIRED` |  |  |  |

Пустая строка не означает согласование. Агент не переходит через checkpoint без
явного ответа разработчика.

После паузы или смены агента работа возобновляется с `Текущий stage` и последнего
checkpoint. Уже принятые этапы не генерируются повторно.
