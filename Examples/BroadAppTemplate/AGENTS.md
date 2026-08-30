# Инструкция агенту: backend-каталог и RU Billing

Этот файл действует для `BroadAppTemplate` и для нового host app, созданного из
него. Цель — сначала выяснить реальный backend-контракт, а затем подключить
платформу без копирования секретов и legacy-костылей из reference.

## Граница работы

- Reference-приложения исследуются только для чтения. Не исправляй их и не
  коммить в них файлы.
- Не копируй production base URL, Bearer token, API key, email, checkout URL,
  SKU или персональные данные из reference.
- Не выполняй настоящий purchase, restore, RU checkout или cancellation.
- Не начинай Swift-изменения, пока backend-раздел
  `Documentation/AppIntegrationPlan.md` не заполнен и неизвестные значения не
  отмечены `BLOCKED`.

## Сначала проведи evidence-аудит

В host app и выбранном reference найди и выпиши:

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

Ищи не только название service. Проверяй фактические `URLRequest`/endpoint
builders, auth interceptor, DTO, composition root и место, где UI получает
результат.

## Подтверждённая стартовая гипотеза

В свежих 5108, 5109, 5115 и 232 найден один набор путей:

```text
GET  /v1/tokens/products
POST /v1/billing/cloudpayments/checkout
GET  /v1/policy/effective
POST /v1/billing/cloudpayments/cancel
```

Это подсказка для поиска, но не разрешение молча использовать эти endpoints.
Перед кодом задай разработчику/team lead один прямой вопрос:

> Для этого приложения используются те же четыре ручки, Bearer-сессия и форма
> `{ "products": [...] }`, что в актуальных 5108/5109/5115/232? Если нет — дайте
> endpoint/schema или backend owner, у которого их уточнить.

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
- Возврат/закрытие browser sheet не означает оплату. Premium открывается после
  подтверждения entitlement/policy; токены — после подтверждения balance.
- `ru_pay` отсутствует/false/invalid — RU Billing закрыт. Не подставляй true.
- Региональный gate: App Store Storefront `RU/RUS` **или** регион iPhone
  `RU/RUS`; язык, клавиатура, IP и timezone не участвуют.
- Production domain и auth остаются app-owned configuration/dependencies.

## Что показать перед изменениями

Первый результат агента — не код, а короткий отчёт:

```text
REFERENCE EVIDENCE
- catalog: method/path/auth/response shape
- checkout: method/path/body/response
- confirmation: subscription authority + token authority
- cancellation: method/path/response
- differences from current platform contract

QUESTIONS / BLOCKERS
- только неизвестные значения, влияющие на реализацию

PLAN
- app-owned configuration
- platform adapter/composition
- UI states
- safe tests without payment

BACKEND CONTRACT REVIEW REQUIRED
```

К реализации переходи после ответа разработчика. Детальный контракт:
[`../../Documentation/BackendProductCatalog.md`](../../Documentation/BackendProductCatalog.md).

## Если нужен спешл оффер RU Billing

Не считай его обычным Adapty Special Offer и не добавляй отдельный payment
engine. Сначала верни разработчику этот evidence:

```text
RU SPECIAL OFFER EVIDENCE
- app identity: App Store ID + Release bundle ID
- dashboard record: совпавшие immutable ID, product IDs и campaign binding
- campaign authority/state/owner: какая система решает + active/inactive/unknown
- recurring/one-time mode, actual payment route, entitlement duration and legal copy
- RU catalog: schema, price units, coupon marker and exact IDs
- Apple placement and exact product IDs
- campaign gate отдельно от ru_pay gate
- eligibility window отдельно от visual countdown
- checkout request and authoritative confirmation after browser return

QUESTIONS / BLOCKERS
- только неизвестные значения, меняющие реализацию

RU SPECIAL OFFER CONTRACT REVIEW REQUIRED
```

Правила:

- reference app и кабинет исследуй только для чтения;
- не выбирай dashboard app по похожему display name;
- `kind = coupon` — предпочтительный contract; legacy `widgetTitle = kupon`
  преобразует только небольшой app-owned decoder;
- сохраняй весь coupon-массив; если UI нужен один offer, попроси explicit
  exact product ID;
- не копируй ranking reference 232 по году/месяцу/цене;
- если dashboard делает продукты разовыми, а UI обещает регулярные списания,
  поставь `BLOCKED` и запроси backend/team lead/legal review;
- не смешивай campaign gate, strict `ru_pay` и regional gate;
- не копируй 24-часовое eligibility-окно или 10-минутный экранный таймер без
  подтверждения product/team lead;
- возврат из Safari не является success: повторно проверь backend
  policy/entitlement;
- статус эксперимента в одной системе не подменяет gate другой системы;
- при inactive/unknown authoritative campaign, несовпавшем ID или пустом
  catalog ветка закрывается без настоящей оплаты.

Полная инструкция:
[`../../Documentation/RUSpecialOffer.md`](../../Documentation/RUSpecialOffer.md).
