# Статус этапов 6–8 для 5135 Seedance

Дата: 2026-08-23. Этот статус продолжает
[`Project5135Preflight.md`](Project5135Preflight.md) и не подменяет отсутствующее
production-приложение BroadAppTemplate-экраном.

## Этап 6. Функциональная итерация

`BLOCKED` до кода.

Причины:

- отсутствуют ТЗ и утверждённая таблица продуктовых решений;
- нет Git/local project 5135, куда можно безопасно вносить app-owned код;
- reference не выбран;
- backend-матрица не содержит ни одного подтверждённого endpoint/contract;
- exact Figma frame context недоступен.

Платформа уже предоставляет требуемые контракты bootstrap/AppFlow,
subscription/token paywall, special offer, Contact Us, typed analytics и
Debug/Release separation, что доказано Template acceptance. Это не доказывает,
что функции 5135 подключены. Создание кнопок с fixture вместо API запрещено.

## Этап 7. Визуальная итерация

`BLOCKED` до появления app build и точного source frame context.

В Figma видны верхнеуровневые группы onboarding/paywall, settings, history,
photo/video effects и prompts, splash. Но MCP не возвращает design context без
editor/dev-access, а отдельного приложения 5135 для screenshot-to-source
сравнения нет. Поэтому ни один экран 5135 не получает visual `PASS` по факту
наличия похожего BroadAppTemplate UI.

## Этап 8. Внешние конфигурации

`BLOCKED` для активации; `PARTIAL` для инвентаризации.

| Конфигурация | Что известно | Чего не хватает |
|---|---|---|
| Adapty | В Kaiten есть public SDK value и список product names | placements, entitlement/access level, dashboard confirmation |
| App Store Connect | Есть app metadata и product names | текущий product state, agreements/availability, безопасный owner-confirmed access |
| Remote Config | Не описан | keys, defaults, owner и kill-switch policy |
| Special offer | Есть offer product name | eligibility, cooldown, placement и server-time source |
| RU Billing | Требование не подтверждено | явное `N/A` либо полный backend contract |
| Legal/support | Ссылки присутствуют | подтверждение финальности и app flow для Contact Us |
| Analytics | Не описана | event map, destinations, consent и safe fields |
| Backend credentials | В Git не нужны и не искались | способ безопасной доставки runtime auth |

Ни одно внешнее значение не записывалось в код. Реальные purchase, restore,
RU checkout и provider-dashboard mutations не выполнялись.

## Условие разблокировки

ПМ/тимлид передаёт заполненные входы и Git проекта; дизайнер даёт точный Figma
frame context; backend-разработчик заполняет versioned contract. После этого
сначала повторяется preflight до `Можно начинать: ДА`, затем выполняются новая
functional iteration, отдельная visual iteration и configuration readiness.
