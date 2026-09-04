# ADR-0007: простой базовый контракт Adapty

- Статус: принято
- Дата: 2026-08-29
- Дополняет: [ADR-0003](0003-entitlement-authority.md) и
  [ADR-0005](0005-provider-managed-remote-feature-gates.md)

## Контекст

Стандартному приложению для показа paywall нужны public SDK key и соответствие
логических placement реальным Adapty placement ID. Дополнительные identity,
access-level и entitlement-типы в первом примере создавали впечатление, что
разработчик обязан собрать собственную систему проверки поверх Adapty.

Одновременно provider уже возвращает готовый список products. Платформа не
должна угадывать, что оставить, как отсортировать карточки или сколько их
показывать.

## Решение

### Базовая настройка

Обычный anonymous-host передаёт:

1. public Adapty SDK key;
2. `AdaptyPlacementRegistry` с нужными placement ID;
3. app-owned тексты ошибок и UI.

Собственный `AdaptyIdentityProviderProtocol` нужен только приложению с
подтверждённой signed-in identity. Access level не нужен для загрузки и показа
paywall.

### Products

Для subscription, token и Special Offer действует один pipeline:

```text
placement → getPaywall → getPaywallProducts → весь массив 1:1 → UI
```

Платформа не выполняет `filter`, `sort`, `compactMap`, truncate или deduplicate.
Экран обязан выдерживать 0, 1, 2 и N products. Если конкретному приложению нужен
особый subset или layout, это app-owned presentation поверх полного payload.

### Entitlement

Стандартный Apple entitlement source — StoreKit current entitlements. Покупка
или restore не открывают premium до подтверждённого результата StoreKit.

Adapty access-level adapter остаётся advanced extension point для host, который
действительно получает отдельный authoritative server-validated ответ. Он не
показывается как обязательная часть базовой настройки.

### Special Offer

Special Offer остаётся только вторым paywall после закрытия первого без
confirmed purchase/restore. Единственный campaign gate — явный
`special_offer = true` в Remote Config обычного paywall.

Первый подходящий close запускает сохраняемое окно:

```text
24 часа показа → 24 часа cooldown → новое окно
```

State repository и trusted clock обязательны. Cooldown начинается ровно в
момент окончания окна, даже если приложение не запущено. Countdown закрывает
экран на нуле. Flag off, confirmed purchase и restore сбрасывают цикл.

### Token paywall

Token paywall загружает свой placement и показывает все products, которые
вернул provider, в исходном порядке. Платформа не фиксирует два, пять или другое
число пакетов.

## Последствия

- базовая инструкция начинается с key и placements;
- разработчик не копирует identity/verifier boilerplate без реальной задачи;
- внутренние safety boundaries покупок сохраняются;
- platform defaults не подменяют Dashboard catalog;
- временной контракт не подменяется экранным визуальным loop.

## Проверка решения

- `BroadMonetization` module gate компилирует basic и advanced initializer;
- Remote Config matrix подтверждает strict `special_offer` и persisted 24/24 cadence;
- module/integration gates проверяют отсутствие filter/sort/dedup products;
- `BroadAppTemplate` использует StoreKit-only Apple entitlement composition.
