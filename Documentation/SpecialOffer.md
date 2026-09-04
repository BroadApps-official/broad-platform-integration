# Special Offer: два совместимых режима второго paywall

## Коротко

Special Offer — опциональный второй paywall. Проект выбирает **один** resolver
в composition root:

1. стандартный приоритетный флаговый режим с `special_offer = true`;
2. отдельный opt-in режим «кампания по наличию» из BroadMonetization `1.2.0`.

Второй режим не меняет первый и не должен подключаться к уже работающему
флаговому проекту без явного решения host app.

```text
обычный subscription paywall
          |
          | крестик, покупка не подтверждена
          v
загрузка placement special_offer и всех его продуктов
          |
          | special_offer == true
          v
Special Offer с визуальным таймером 24:00:00 -> 00:00:00 -> снова
          |
          | close или подтверждённая покупка/restore
          v
main
```

Special Offer не заменяет initial paywall, не показывается первым при запуске и
не открывается напрямую из main. Демонстрационная карточка каталога также
запускает всю пару: сначала обычный paywall, затем offer после крестика.

Эта страница описывает Adapty-only контракт. Offer с coupon-продуктом из RU
backend, СБП/картой, отдельным eligibility-window и browser reconciliation
описан в [«Спешл оффер RU Billing»](RUSpecialOffer.md).

## Стандартный приоритетный режим: флаговый resolver

### Что включает и выключает offer

Для показа одновременно нужны три условия:

1. host передал `SpecialOfferConfiguration`;
2. стандартный loader вернул payload нужного placement с продуктами;
3. текущий provider payload содержит валидный `special_offer = true`.

Если host передал `nil`, resolver немедленно возвращает
`.unavailable(.notConfigured)` и не трогает network, cache или UI:

```swift
let result = await resolveSpecialOffer(
    configuration: appConfiguration.specialOffer
)
```

Отсутствующий, невалидный или ложный флаг возвращает
`.unavailable(.disabledByRemoteConfiguration)`. Прошлое `true` не
восстанавливается из last-valid cache.

| Provenance payload | Обычный paywall | `special_offer = true` может открыть offer |
|---|---:|---:|
| `.verifiedFreshRemote` | да | да |
| `.providerCacheFallbackPossible` | да | да |
| `.platformCache` | да | нет |
| `.legacyUnqualified` | да | нет |

`.providerCacheFallbackPossible` — нормальный provenance текущего результата
публичного Adapty SDK: SDK может прозрачно использовать свой managed cache, не
раскрывая origin. `.platformCache` означает сохранённую самой
BroadMonetization копию; она не имеет права заново включать кампанию.

> Важно: разрешение Special Offer и разрешение RU Billing — две независимые
> capability. Special Offer допускает `.providerCacheFallbackPossible`, а
> Release-правило `ru_pay` остаётся строгим и требует `.verifiedFreshRemote`.

## Загрузка и парсинг подписок

Используется стандартная Adapty-последовательность:

```text
Adapty.getPaywall(placement)
          v
Adapty.getPaywallProducts(paywall)
          v
map каждого product occurrence 1:1 в исходном порядке
          v
сохранение пары mapped reference <-> raw Adapty product в registry
          v
парсинг Remote Config и создание PaywallPayload
          v
resolver проверяет special_offer и выдаёт presentationAuthorization
```

Gate не стоит перед `getPaywallProducts`: сначала загружается полный каталог,
затем принимается решение о показе. Платформа не создаёт словарь по product ID,
не сортирует и не удаляет дубликаты. Поэтому два occurrence одного SKU остаются
двумя строками, а покупка получает raw `AdaptyPaywallProduct`, соответствующий
именно выбранному `ProductPresentationID`.

Отдельный REST-запрос, кастомный paywall repository и ручное наполнение product
registry не нужны. Ожидаемый SKU нельзя хардкодить как замену provider product:
если его нет в ответе, это проблема конфигурации Adapty/App Store Connect.

## Таймер — только визуальный

Таймер не является сроком действия предложения и не участвует в eligibility:

- стартует с `24:00:00` при создании presentation authorization;
- уменьшается раз в секунду;
- показывает `00:00:00`;
- на следующем тике снова показывает `24:00:00`;
- не скрывает paywall, не снимает выбор продукта и не запрещает purchase;
- не использует `Date()`, server time, Keychain/UserDefaults или backend;
- не переживает presentation как campaign state: новый показ получает новый
  визуальный цикл.

Legacy-поля `windowDuration` и `cooldownDuration`, старые state repository и
`SpecialOfferClock` оставлены source/decoding-compatible для существующих host
apps, но стандартный resolver их не читает. Малформатное duration-поле больше не
может перевести явный `special_offer = true` в false.

## Параллельный opt-in режим: кампания по наличию

Этот путь использует `ResolveSpecialOfferCampaignUseCase`. Он подходит проекту,
где сам опубликованный paywall собственного placement означает наличие
кампании, а обязательного `special_offer = true` рядом с ним нет.

Кампания доступна только когда одновременно выполнены условия:

- активная подписка не подтверждена;
- server time синхронизирован (политика по умолчанию — fail-closed);
- provider вернул paywall именно запрошенного campaign placement, без fallback;
- payload не восстановлен из platform cache и разрешает presentation;
- `special_offer` не равен явному `false` — отсутствующий ключ нейтрален;
- полный массив продуктов не пуст.

Каталог остаётся provider-owned: все occurrence передаются 1:1 в исходном
порядке, включая дубли SKU. Фильтрация, сортировка, `prefix`, словарь по product
ID и выбор «нужных» продуктов запрещены так же, как в стандартном режиме.

`SpecialOfferCadence` хранит сутки доступного оффера, затем сутки тишины.
Границы вычисляются по `ServerTimeProviderProtocol`; часы устройства не
используются без явной осознанной политики host app. Подтверждённая purchase или
restore очищает окно, а активная подписка отсекается до paywall/cache/network.

`SpecialOfferCampaignCoordinator` слушает обычные monetization events: после
закрытия отслеживаемого subscription paywall без покупки публикует решение в
`decisions`, не следует за campaign placement и гасит окно после purchase или
restore.

```swift
let campaignConfiguration = SpecialOfferCampaignConfiguration(
    placementID: .specialOffer
)
let campaignResolver = ResolveSpecialOfferCampaignUseCase(
    configuration: campaignConfiguration,
    loadPaywallUseCase: services.loadPaywall,
    windowRepository: PersistedSpecialOfferWindowStore(store: keyValueStore),
    presentationLifecycle: services.paywallPresentationLifecycle,
    entitlementStatusProvider: entitlementEngine,
    serverTime: serverClock
)
let campaignCoordinator = SpecialOfferCampaignCoordinator(
    resolve: campaignResolver,
    followedPlacementIDs: [.main]
)
await analyticsRelay.connect(campaignCoordinator)

for await outcome in campaignCoordinator.decisions {
    guard case let .campaign(campaign) = outcome else { continue }
    present(
        placementID: campaign.placementID,
        remaining: campaign.remainingTimeInterval
    )
}
```

Resolver возвращает placement, а не повторно используемый payload: экран
загружает этот placement сам и владеет своей presentation. Decision-
presentation resolver завершает самостоятельно.

Исполняемая проверка точек цикла стандартного режима:

```bash
bash Scripts/check_special_offer_runtime_contract.sh
```

## Подключение

Новая composition не требует clock или persistence:

```swift
let resolveSpecialOffer = ResolveSpecialOfferUseCase(
    loadPaywallUseCase: services.loadPaywall,
    presentationLifecycle: services.paywallPresentationLifecycle
)

let specialOffer = SpecialOfferConfiguration(
    placementID: .specialOffer
)
```

При успешном resolution повторно загружать placement нельзя. Передайте готовый
payload как `initialPayload`, а authorization — в UI configuration:

```swift
let result = await resolveSpecialOffer(configuration: specialOffer)

guard let payload = result.paywall,
      let authorization = result.presentationAuthorization
else {
    // Продолжить в main без пустого промежуточного экрана.
    return
}

let configuration = BroadPaywallConfiguration(
    placementID: payload.origin.requestedPlacementID,
    specialOfferAuthorization: authorization
)
let viewModel = PaywallViewModel(
    configuration: configuration,
    dependencies: paywallDependencies,
    initialPayload: payload
)
```

Authorization связан с конкретным `PaywallPresentationID`; переносить его на
другой payload нельзя. Lifecycle освобождает provider presentation при disabled
gate, неверном origin, cancellation или после окончания UI.

## Placement и fallback

Resolver запрашивает placement из `SpecialOfferConfiguration`. Fallback на
`main` допустим только если:

- requested placement остаётся configured Special Offer placement;
- resolved placement равен `.main`;
- именно полученный `main` payload содержит `special_offer = true`;
- provenance разрешает Special Offer.

Если самостоятельный `special_offer` placement успешно загрузился, флаг читается
из него. Один флаг на `main` не включает другой успешно загруженный payload.

## Что показывает UI

Remote display-поля остаются optional. Платформа не придумывает:

- зачёркнутую цену или числовое значение;
- множитель;
- текст периода;
- badge.

UI показывает только пришедшие metadata и полный массив products. Таймер входит
в presentation authorization платформы и показывается независимо от optional
metadata.

## Flow после действий пользователя

- крестик initial paywall без подтверждённой покупки — запустить resolver;
- disabled/unavailable offer — сразу перейти в main;
- close Special Offer — перейти в main;
- verified purchase/restore на любом paywall — вызвать общий
  `subscriptionDidBecomeActive()` и перейти в main;
- pending/cancel/error/unverified — не выдавать premium.

`initialPaywallDismissed()` вызывается после отрицательного результата resolver
или после закрытия Special Offer. Так policy первой презентации учитывает всю
ветку и не создаёт loop `main -> paywall -> offer`.

## Безопасная проверка без покупки

Fixture-аргументы запускают настоящий порядок экранов:

| Аргумент | Ожидание |
|---|---|
| `-special-offer-enabled` | после крестика первого paywall показывается offer |
| `-special-offer-disabled` | после крестика открывается main |
| `-special-offer-main-fallback` | offer приходит через разрешённый `main` fallback |
| `-special-offer-platform-cache` | platform cache не включает offer |
| `-special-offer-looping-timer` | виден цикл 24:00:00 -> 00:00:00 -> 24:00:00; offer остаётся активным |

Для live Adapty без purchase/restore зафиксируйте:

1. requested/resolved placement и provenance;
2. `special_offer` именно текущего payload;
3. число продуктов и product ID в provider order;
4. переход `[FLOW] ... from=initial-paywall to=special-offer`;
5. возможность выбрать продукт до и после визуального нуля таймера.

Наглядная пара экранов находится в
[главном README](../README.md#special-offer-sequence).
