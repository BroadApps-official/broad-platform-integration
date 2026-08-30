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

## Что доказано по reference 232

Reference `232` исследован только для чтения 30 августа 2026 года. Текущая
Release-сборка имеет App Store ID `6758451701`, а её product IDs записаны в
lowercase, например `monthly_12.99_nottrial` и `100_tokens_9.99`.

В платёжном кабинете найдены три близкие записи:

| Запись | Что совпало | Что не совпало | Вывод |
|---|---|---|---|
| `232 Claude` | App Store ID, полный регистрозависимый набор product ID, привязка coupon/downsell-экспериментов | старое display name | **Reference для текущего кода 232** |
| `232 Claude AI New T-Bank` | lowercase product IDs | нет доказанной привязки к текущему App Store ID/эксперименту | похожая копия, не выбирать по имени |
| `232 Claimva AI Chatbot (Т-Банк)` | текущее название приложения | token IDs записаны с другим регистром | другая копия конфигурации |

Три признака должны совпасть одновременно: неизменяемый ID приложения, точные
product IDs и фактическая привязка кампании. Display name недостаточно.

В кабинете связанные с `232 Claude` варианты «купон/дожим» на момент аудита
были неактивны. При этом код 232 читает runtime-флаг `kupon` из Adapty. Статус
эксперимента в RU-кабинете и Adapty-флаг могут быть разными системами. Поэтому
**нельзя обещать production-показ**, пока владелец не назвал текущую campaign
authority и rollout. Документация описывает рабочий кодовый маршрут, а не
утверждает, что кампания сейчас включена или выключена.

### Важное расхождение 232 перед следующим rollout

У рабочей записи 232 включён режим «сделать все продукты разовыми», хотя
локальный UI называет discount subscription рекуррентной и просит согласие на
регулярное списание. Код создаёт checkout по CloudPayments-path, а служебное
поле кабинета называет другой payment gateway.

Это не причина менять общий package и не доказательство бага провайдера, но это
**release blocker конкретного app**, пока backend owner, тимлид и legal не
подтвердят:

1. покупка разовая или автоматически продлеваемая;
2. какой текст согласия должен видеть пользователь;
3. кто продлевает entitlement и на какой срок;
4. какой payment route фактически production;
5. что означает cancellation для этой покупки.

Платформа не копирует dashboard toggle, provider label или legal copy из 232.

## Фактический маршрут 232

В 232 используются два независимых источника:

1. placement Adapty `kupon` даёт Apple-продукт;
2. RU backend catalog отдаёт подписки, среди которых reference ищет строки с
   `widgetTitle = kupon`.

Оба запроса запускаются параллельно. Если RU-каталог недоступен, Apple-вариант
может остаться доступным. Если период Apple-продукта отличается от периода
выбранного RU-продукта, reference скрывает Apple-вариант, чтобы один экран не
показывал одну цену, а не покупал другой срок.

Reference 232 затем сортирует найденные coupon-строки по собственной
приоритетной таблице. **Это app-specific legacy policy, а не правило
платформы.** Новый app не должен угадывать «лучший» offer по году, месяцу, цене
или позиции. Backend должен вернуть `kind = coupon`, либо host обязан явно
передать точный coupon product ID. Если разрешено несколько предложений,
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

### Если backend отдаёт legacy `widgetTitle = kupon`

Так устроен reference 232, но это не универсальная схема. App-owned decoder
должен явно преобразовать только подтверждённые backend-поля:

```text
product_id / productId  → catalogProductID
widgetTitle == kupon    → kind = coupon
period                  → subscriptionPeriod
price                   → Money в подтверждённой единице
```

Не переносите production URL, authorization value или bundle ID из 232. Для
нового приложения эти значения предоставляет его backend owner.

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

## Два таймера 232 — не смешивать

Reference содержит два разных механизма:

| Механизм | Что делает | Где хранится | Что происходит на нуле |
|---|---|---|---|
| 24-часовое eligibility-окно | решает, можно ли снова открыть offer между показами | `UserDefaults` reference app | предложение больше не показывается |
| 10-минутный UI countdown | создаёт срочность на открытом экране | только state текущего экрана | экран закрывается, кроме незавершённой проверки оплаты |

Это **не** 24-часовой циклический визуальный таймер Adapty Special Offer.
Платформа пока не назначает общий default RU-таймера. Для каждого app в
`AppIntegrationPlan` отдельно фиксируются:

- существует ли eligibility-window;
- его длительность и момент старта;
- переживает ли он переустановку/смену аккаунта;
- существует ли визуальный countdown;
- закрывает ли ноль экран;
- что происходит, если пользователь вернулся из Safari после нуля.

Если ответы не подтверждены product/team lead, timer policy получает `BLOCKED`,
а не копируется из 232.

## Checkout и возврат из браузера

Reference передаёт в checkout **точный** resolved RU product ID. Затем открывает
полученный HTTPS URL в Safari. Сам факт возврата в приложение ничего не
подтверждает.

После возврата 232 ограниченно повторяет:

1. синхронизацию backend subscription;
2. загрузку effective policy текущего app account;
3. временный legacy status fallback;
4. паузу перед следующим запросом.

Только подтверждённый `isSubscribed/active` завершает покупку. Количество
попыток и задержка — app-owned retry policy, а не финансовая истина. Timeout
оставляет результат неизвестным и разрешает безопасно повторить проверку, но не
создаёт новый checkout автоматически.

## Пошаговая инструкция разработчику

1. Запишите App Store ID, Release bundle ID и полный список product ID из app.
2. В кабинете найдите запись, где совпадают immutable app ID, product IDs с
   учётом регистра и активная campaign binding. Не выбирайте по названию.
3. Уточните у тимлида, какая система является campaign authority, активна ли
   RU Special Offer-кампания и кто владеет rollout. Для 232 код читает Adapty
   `kupon`, а аудит RU-кабинета увидел неактивные эксперименты.
4. Сверьте recurring/one-time mode, actual payment route, entitlement duration,
   cancellation и legal copy. Любое противоречие получает `BLOCKED`.
5. Получите app-owned catalog endpoint, schema, authorization dependency и
   единицу цены. Не копируйте их из reference.
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
RU SPECIAL OFFER EVIDENCE
- app identity: App Store ID + Release bundle ID
- dashboard record: почему выбрана именно она
- campaign: authority + owner + active/inactive/unknown
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

Агент не должен изменять reference app, кабинет, цены или experiment state;
копировать URL/authorization; выбирать продукт сортировкой; считать browser
return оплатой; включать RU Billing по языку; создавать отдельный entitlement
engine для offer.

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
