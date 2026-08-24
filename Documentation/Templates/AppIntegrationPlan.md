# App Integration Plan

> Скопируйте этот файл в `Documentation/AppIntegrationPlan.md` repository
> конкретного приложения. Не добавляйте credentials или персональные данные.

## 0. Контекст

| Поле | Значение |
|---|---|
| Режим | `new app` / `existing app` |
| App target / workspace |  |
| Текущий stage |  |
| Последний подтверждённый checkpoint |  |
| Ссылка на source requirements |  |

Для `existing app` сначала перечислите current behavior и gaps. Не создавайте
второй target и не переписывайте подтверждённые части до review плана.

## 1. Статус входов

| Вход | Источник | Статус `READY/BLOCKED/N/A` | Владелец blocker-а |
|---|---|---|---|
| Kaiten / требования |  |  |  |
| Design source |  |  |  |
| Reference read-only |  |  |  |
| Backend contracts |  |  |  |
| Monetization decisions |  |  |  |
| Support/legal |  |  |  |

## 2. Ownership

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

## 3. Карта экранов и состояний

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

## 4. Backend и hooks

| Функция | Method/endpoint или SDK | Request/response schema | Обязательные поля | Auth | Retry/offline | Server-owned hook/result | Статус |
|---|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |  |

`READY` ставится только после contract smoke по согласованной schema или
обезличенному production-shape fixture. Локальная заглушка, кнопка или успешная
компиляция не доказывают backend.

## 5. Монетизация

| Решение | Выбранный вариант | Источник | Статус |
|---|---|---|---|
| Initial paywall | once / every cold launch / disabled |  |  |
| Premium authority |  |  |  |
| Tokens | enabled / disabled + fulfillment endpoint |  |  |
| Special Offer | enabled / disabled + placement/gate |  |  |
| RU Billing | enabled / disabled + backend/legal |  |  |
| Recovery | Apple/backend + account token balance endpoint; processed purchase IDs остаются backend-internal |  |  |

### RU Billing: заполнить, если feature не `N/A`

| Вопрос | Решение / evidence | Статус |
|---|---|---|
| Host composition и backend/legal подключены? |  |  |
| Какое production-значение `ru_pay`? | `true` / `false`; владелец флага |  |
| Как доказывается freshness? | Endpoint/schema/TTL/offline policy; `.verifiedFreshRemote` только после network response |  |
| Где backend kill switch? | Endpoint/policy и владелец |  |
| Debug override подключён? | `Как в Adapty` / force-on / force-off; только Debug |  |
| Какой live smoke пройден? | Verified `true/false`; provider/platform cache rejection; без purchase |  |

Release не может иметь app-default или force override для `ru_pay`.
Fixture/Debug force-on не считается evidence freshness, backend или успешной оплаты.

## 6. Вертикальные срезы

| Порядок | Срез | Вход → итог | Зависимости | Статус | Developer review |
|---:|---|---|---|---|---|
| 1 |  |  |  |  |  |

Каждый срез проходит `View → ViewModel → use case → repository → client` и
заканчивается `SLICE REVIEW REQUIRED` до начала следующего.

## 7. Blockers

| Функция | Чего нет | Где проверено | Владелец | Что можно продолжить независимо |
|---|---|---|---|---|
|  |  |  |  |  |

## 8. Checkpoints

| Checkpoint | Статус | Кто подтвердил | Evidence |
|---|---|---|---|
| `PLAN REVIEW REQUIRED` |  |  |  |
| `SKELETON REVIEW REQUIRED` |  |  |  |
| `FUNCTIONAL REVIEW REQUIRED` |  |  |  |
| `VISUAL REVIEW REQUIRED` |  |  |  |
| `READY FOR QA` |  |  |  |

Пустая строка не означает согласование. Агент не переходит через checkpoint без
явного ответа разработчика.

После паузы или смены агента работа возобновляется с `Текущий stage` и последнего
checkpoint. Уже принятые этапы не генерируются повторно.
