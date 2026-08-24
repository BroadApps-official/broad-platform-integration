# Внезапно пропал интернет

Для нестабильной мобильной сети недостаточно проверить internet один раз перед
экраном. Связь может исчезнуть после tap, во время ответа или между оплатой и
подтверждением backend.

## Главное правило

```text
read operation failed       → safe offline/timeout + cache/manual retry
financial result uncertain  → pending + reconcile, НИКОГДА не charge again
server write uncertain      → query current server state before resubmitting
```

`NWPathMonitor` или аналогичный indicator может улучшать UI, но не доказывает,
что конкретный запрос дойдёт. Источник правды — результат самой операции.

## Что делает платформа

- `NetworkFailureClassifier` безопасно различает `offline`, `timedOut`,
  `cancelled` и прочие ошибки без raw URL/error text;
- RU URLSession clients не ждут соединение бесконечно
  (`waitsForConnectivity = false`) и имеют конечные request timeouts;
- RU UI получает retryable `AppError.kind == .offline/.timeout`;
- RU payment polling сразу останавливается при offline/timeout, не тратит все
  попытки и не удаляет pending checkout;
- Apple/Adapty purchase с неопределённым результатом остаётся `.pending`;
- token evidence/intent остаётся до idempotent backend fulfillment;
- entitlement network failure становится `.unresolved`, а не ложным inactive;
- ранее подтверждённый active может использовать только конечный offline grace.

## Поведение по точкам отказа

| Где пропала сеть | Что видит пользователь | Что остаётся сохранено | Как продолжить |
|---|---|---|---|
| Загрузка paywall/catalog | cached/stale UI либо error + Retry | безопасный catalog cache | повторить read после появления связи |
| До Apple sheet | retryable error | charge не начинался | разрешён ручной retry |
| Во время Apple purchase | «Покупка подтверждается» | durable Apple intent | StoreKit reconciliation на foreground |
| После StoreKit, до token backend | баланс не увеличивается локально | intent + verified JWS | `recoverPendingPurchase()` |
| До открытия RU payment URL | offline/timeout | access не выдан | сначала проверить pending/server state; старый неоткрытый session должен безопасно истечь |
| После открытия RU payment URL | «Проверяем оплату» | pending RU session | новый status poll после foreground/Retry |
| При отмене RU subscription | offline/timeout | текущий access не меняется локально | сначала reload status; cancel endpoint должен быть idempotent |
| Fresh-install recovery | unknown/unavailable, не zero | server state не меняется | повторить recovery после связи |

## Что можно повторять автоматически

Допустим bounded retry только для идемпотентных чтений:

- paywall/catalog load;
- entitlement/status load;
- token balance recovery;
- проверка RU payment status.

Не запускайте автоматически повторный Apple purchase, новый RU checkout,
token charge или cancellation POST. Для них сначала восстановите pending/current
server state. Даже событие «internet снова online» не является разрешением на
новое списание.

## Host/backend contract

1. Все запросы имеют конечный timeout.
2. Backend атомарно обрабатывает каждый StoreKit transaction ID один раз;
   повтор evidence возвращает текущий account balance без второго начисления.
3. RU checkout creation не списывает деньги сам по себе; неоткрытая session
   безопасно истекает. После ambiguous response host сначала проверяет
   pending/server state и только затем разрешает пользователю новый checkout.
4. RU payment status и cancellation безопасно повторяются по server ID.
5. После network ambiguity backend status проверяется до нового write.
6. UI сохраняет предыдущий verified value, показывает offline/stale состояние и
   одну guarded Retry action.
7. Retry single-flight: быстрые повторные taps не запускают параллельные задачи.

## Ручные сценарии без StoreKit sandbox

Для интеграции приложения вручную переключите Network Link Conditioner или
соединение Simulator в каждой точке таблицы. Проверяйте:

- loader заканчивается конечным offline/timeout, а не висит бесконечно;
- старый verified premium не превращается в inactive из-за сети;
- новая покупка не выдаёт premium без fresh confirmation;
- повторный tap не создаёт второй financial operation;
- RU pending survives background/foreground и status retry;
- token balance не меняется до server snapshot;
- после восстановления сети read/reconciliation заканчивает flow без нового
  charge.

[Cache & Offline →](CachingAndOffline.md) · [Entitlements →](Entitlements.md) ·
[Purchase Managers →](PurchaseManagers.md) · [RU Billing →](RUBilling.md)
