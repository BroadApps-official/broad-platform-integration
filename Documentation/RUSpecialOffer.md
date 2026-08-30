# Спешл оффер RU Billing

## Что это такое

Спешл оффер RU Billing — второй экран предложения после закрытия обычного
subscription paywall. На нём пользователь может выбрать Apple либо российскую
оплату, если конкретный способ действительно доступен.

Это **не** тот же контракт, что
[«Special Offer от Adapty»](SpecialOffer.md):

| | Special Offer от Adapty | Спешл оффер RU Billing |
|---|---|---|
| Откуда продукт | placement Adapty | RU backend catalog; Apple-вариант может параллельно прийти из Adapty |
| Чем включается | `special_offer = true` текущего payload | app-owned campaign gate + подтверждённый RU Billing gate для СБП/карты |
| Оплата | Apple purchase | Apple либо внешний RU checkout |
| Подтверждение | entitlement refresh | entitlement/backend policy после возврата из браузера |
| Таймер | визуальный цикл 24 часа | отдельные eligibility и UI-политики приложения; общего default пока нет |

Один экран может поддерживать оба способа, но разрешения независимы: отсутствие
RU-доступа не запрещает Apple-вариант, а наличие RU-каталога само по себе не
разрешает СБП или карту.

## Понятная схема

```text
обычный subscription paywall
  ├─ подтверждённая покупка/restore → main
  └─ крестик без покупки
       ↓
campaign gate разрешил дополнительное предложение?
  ├─ нет / неизвестно / эксперимент неактивен → main
  └─ да
       ↓
загрузить offer-каталоги
  ├─ Adapty placement → Apple-вариант
  └─ RU backend catalog → coupon-продукты для СБП/карты
       ↓
показать только способы с точным продуктом и пройденным gate
       ↓
Apple purchase ИЛИ RU hosted checkout
       ↓
новая entitlement/backend-проверка
  ├─ active → Premium + main
  ├─ pending/timeout → «проверяем оплату», повтор проверки
  └─ inactive/failed → Premium не выдавать
```

## Что получает разработчик до начала работы

Разработчик не настраивает и не исследует платёжный кабинет. Ответственная
команда передаёт готовый контракт текущего приложения:

| Входное значение | Что должно быть подтверждено |
|---|---|
| campaign source/key | система-источник, точный ключ и разрешающее значение |
| RU coupon | exact case-sensitive product ID и период |
| Apple-вариант | placement, exact product ID и период, если Apple разрешён |
| тип покупки | one-time или recurring, срок Premium и cancellation semantics |
| backend | catalog, checkout и status/policy methods, schema, auth dependency и price units |
| способы оплаты | Apple, СБП и/или карта |
| таймеры | eligibility и visual countdown как два отдельных решения |
| UI | тексты, цены, скидка, изображения, legal links и analytics names |

Если обязательного значения нет или ответы противоречат друг другу,
разработчик задаёт вопрос тимлиду и не угадывает production-контракт.

Apple placement и RU backend catalog загружаются независимо. Если RU-каталог
недоступен, валидный Apple-продукт может остаться. Если периоды Apple и RU не
совпадают, несовместимый способ скрывается, чтобы экран не обещал один срок и
не покупал другой.

Backend должен вернуть `kind = coupon`, либо host явно передаёт точный coupon
product ID через подтверждённый decoder. Если разрешено несколько предложений,
платформа сохраняет и показывает их все в порядке backend.

## Как продукт должен выглядеть в платформе

`BroadMonetization` уже поддерживает `RUCatalogProductKind.coupon` и секцию
`RUCatalogSections.coupons`. Отдельные `BroadRUSpecialOffer`, второй transport
или новый entitlement engine не нужны.

Рекомендуемый JSON:

```json
{
  "products": [
    {
      "productId": "premium_offer_month_ru",
      "appStoreProductId": "premium_offer_month",
      "title": "Premium по специальной цене",
      "kind": "coupon",
      "period": "month",
      "price": 799,
      "currency": "RUB",
      "paymentMethods": ["sbp", "card"]
    }
  ]
}
```

`price` здесь — основные единицы валюты. Если backend отдаёт minor units или
другой envelope, host предоставляет свой `RUCatalogResponseDecoderProtocol`.

### Если backend отдаёт legacy marker

App-owned decoder должен явно преобразовать только подтверждённые backend-поля:

```text
product_id / productId  → catalogProductID
widgetTitle == kupon    → kind = coupon
period                  → subscriptionPeriod
price                   → Money в подтверждённой единице
```

Не переносите production URL, authorization value или product ID из другого
приложения. Для текущего приложения эти значения передаёт его владелец.

## Четыре независимых разрешения

Перед показом RU-кнопки должны пройти четыре проверки:

1. **Кампания:** дополнительное предложение разрешено текущим app-owned
   authoritative config/экспериментом. Статус записи в другой системе сам по
   себе ничего не включает и не выключает.
2. **RU Billing:** host включил feature, verified-fresh payload содержит
   `ru_pay = true`, а Storefront равен `RU/RUS` **или** регион iPhone равен
   `RU/RUS`.
3. **Продукт:** coupon найден по exact case-sensitive ID либо по явной mapping
   table host app. Похожее имя, цена или период не являются соответствием.
4. **Backend:** checkout разрешён сервером, а после браузера authoritative
   policy/entitlement подтвердил `active`.

Язык, клавиатура, IP и timezone не включают RU Billing. Отсутствующий,
`false`, некорректный или несвежий `ru_pay` оставляет Apple-only.

## Два таймера — не смешивать

Flow может содержать два разных механизма:

| Механизм | Что делает | Где хранится | Что происходит на нуле |
|---|---|---|---|
| eligibility-окно | решает, можно ли снова открыть offer между показами | app-owned persistent state | следующий показ блокируется до разрешённой даты |
| UI countdown | создаёт срочность на открытом экране | state текущего экрана | поведение задаёт подтверждённая спецификация |

Это **не** 24-часовой циклический визуальный таймер Adapty Special Offer.
Платформа пока не назначает общий default RU-таймера. Для каждого app в
`AppIntegrationPlan` отдельно фиксируются:

- существует ли eligibility-window;
- его длительность и момент старта;
- переживает ли он переустановку/смену аккаунта;
- существует ли визуальный countdown;
- закрывает ли ноль экран;
- что происходит, если пользователь вернулся из Safari после нуля.

Если ответы не подтверждены product/team lead, timer policy получает `BLOCKED`.

## Checkout и возврат из браузера

Host передаёт в checkout **точный** resolved RU product ID. Затем открывает
полученный HTTPS URL в Safari. Сам факт возврата в приложение ничего не
подтверждает.

После возврата приложение ограниченно повторяет:

1. синхронизацию backend subscription;
2. загрузку effective policy текущего app account;
3. временный legacy status fallback;
4. паузу перед следующим запросом.

Только подтверждённый `isSubscribed/active` завершает покупку. Количество
попыток и задержка — app-owned retry policy, а не финансовая истина. Timeout
оставляет результат неизвестным и разрешает безопасно повторить проверку, но не
создаёт новый checkout автоматически.

## Пошаговая инструкция разработчику

1. Получите подтверждённый набор входных значений из таблицы выше.
2. Выпишите отсутствующие или противоречивые значения и дождитесь ответа тимлида.
3. Зафиксируйте campaign authority, key, rollout и exact product IDs.
4. Сверьте recurring/one-time mode, entitlement duration, cancellation и legal copy.
5. Получите app-owned catalog endpoint, schema, authorization dependency и единицу цены.
6. Настройте backend `kind = coupon` либо небольшой decoder legacy-поля
   `widgetTitle = kupon`.
7. Сохраните весь coupon-массив, порядок и дубли. Если UI нужен один продукт,
   передайте его exact ID явной конфигурацией.
8. Отдельно задайте campaign gate, RU Billing gate и timer policy.
9. Загружайте Apple и RU-варианты независимо. Не блокируйте валидный Apple
   product из-за недоступности RU backend.
10. Перед checkout ещё раз проверьте gate и текущий Storefront/регион.
11. Отправьте exact RU product ID, откройте только HTTPS payment URL и сохраните
    pending session.
12. После browser return запросите authoritative entitlement/policy. `active`
    открывает Premium; pending/timeout показывают проверку, но не success.
13. Проверьте close, inactive experiment, пустой catalog, несовпавший ID,
    Apple-only, RU-only и возврат после истечения UI-таймера без реальной оплаты.

## Инструкция агенту

Перед Swift-изменениями агент обязан вернуть:

```text
RU SPECIAL OFFER GIVEN
- campaign: authority + key + active/inactive/unknown
- billing semantics: recurring/one-time + actual route + entitlement duration
- catalog: method/path/auth dependency/schema/price units
- coupon marker: kind=coupon или подтверждённое legacy-поле
- exact product IDs and optional explicit mapping
- Apple placement and period policy
- campaign gate, ru_pay provenance and RU region rule
- eligibility window and visual timer as separate decisions
- checkout request/payment URL/authoritative confirmation

QUESTIONS / BLOCKERS
- только неизвестные значения, меняющие реализацию

PLAN
- app-owned configuration
- decoder/mapping
- UI states
- safe manual checks without a real payment

RU SPECIAL OFFER CONTRACT REVIEW REQUIRED
```

Агент не должен открывать платёжный кабинет, копировать значения другого
приложения, выбирать продукт сортировкой, считать browser return оплатой,
включать RU Billing по языку или создавать отдельный entitlement engine.

## Что мы намеренно не добавили

- отдельные package targets для coupon flow;
- второй RU transport или новый payment manager;
- platform-wide product ranking;
- общий hardcode таймера по поведению одного приложения;
- автоматическое включение кампании или `ru_pay`;
- unit tests и настоящие финансовые операции в integration repository.

Текущих `BroadMonetization`, `RUCatalogProductKind.coupon`,
`RUCatalogSections.coupons`, exact mapping и общего entitlement refresh
достаточно. Остальное — небольшая app-owned конфигурация и понятный UI.

[RU Billing →](RUBilling.md) ·
[Backend product catalog →](BackendProductCatalog.md) ·
[Special Offer от Adapty →](SpecialOffer.md) ·
[Integration Plan →](Templates/AppIntegrationPlan.md)
