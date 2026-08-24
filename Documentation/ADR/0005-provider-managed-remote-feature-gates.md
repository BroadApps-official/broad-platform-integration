# ADR-0005: provider-managed Remote Config и финансовый доступ

- Статус: принято
- Дата: 2026-08-22
- Обновлено: 2026-08-24

## Контекст

Этот ADR заменяет только provenance-часть
[ADR-0004](0004-ru-billing-fallback.md). Остальные условия RU Billing из
ADR-0004 не меняются.

Стандартный `AdaptyPaywallRepository` загружает paywall, продукты и Remote
Config одним вызовом Adapty SDK. SDK может прозрачно использовать собственный
cache и не сообщает через public API, пришёл ли конкретный payload из сети или
из provider-managed cache. Поэтому repository честно отмечает такой payload как
`.providerCacheFallbackPossible`.

Один общий capability для `special_offer` и `ru_pay` создавал неверную связь:
достижимость визуального Special Offer одновременно ослабляла финансовый
RU gate до provider cache. Эти решения должны иметь разную provenance-матрицу.

## Решение

Разделяются две независимые ответственности.

### Special Offer capability

Текущий payload стандартного Adapty SDK может управлять показом Special Offer
при явном `special_offer = true`.

Эти UI-возможности разрешены для:

- `.verifiedFreshRemote`;
- `.providerCacheFallbackPossible`.

Они запрещены для:

- `.platformCache` — payload восстановлен самой платформой;
- `.legacyUnqualified` — источник старого payload неизвестен.

Отсутствующий, malformed или explicit `false` gate остаётся fail-closed.
Предыдущее положительное значение не переносится в новый payload.

### RU Billing capability

`ru_pay = true` разрешает RU methods только для `.verifiedFreshRemote`.
`.providerCacheFallbackPossible`, `.platformCache` и `.legacyUnqualified` остаются
fail-closed. Отрицательный/absent/invalid `ru_pay` закрывает feature при любом
provenance.

### Authoritative entitlement

Remote Config никогда не подтверждает финансовый результат. Ни один из его
флагов не может самостоятельно:

- открыть premium;
- подтвердить подписку;
- начислить или восстановить токены;
- подтвердить RU-покупку.

После Apple purchase/restore или RU return приложение запускает новый
authoritative entitlement refresh. Доступ открывает только подтверждённый
`.active` от настроенных Apple/backend/RU sources.

## Почему не используется собственный Adapty REST transport

Платформа сохраняет единый стандартный Adapty-путь. Она не открывает внутренний
product registry, не повторяет приватный provider API и не создаёт второй
источник experiment assignment. Один payload продолжает связывать variation,
provider show, продукты и последующую покупку.

## Cache и fallback

Provider-managed cache и platform cache имеют разные права:

| Источник | Обычный paywall | Special Offer | RU Billing |
|---|---:|---:|---:|
| verified remote | да | да | да |
| текущий payload Adapty SDK | да | да | нет |
| cache BroadMonetization | да | нет | нет |
| legacy/unqualified payload | да | нет | нет |

Dashboard-generated fallback, зарегистрированный через
`Adapty.setFallback(fileURL:)`, относится к текущему payload Adapty SDK.
Он сохраняет свои продукты, variation и Remote Config для paywall/Special Offer,
но не доказывает свежесть `ru_pay`.

Fallback на `main` использует Remote Config фактически resolved payload. Он не
переносит положительный gate с requested placement.

Debug-only force-on/off — узкое исключение для проверки UI/gate.
Оно не меняет provider payload, не персистится, не обходит остальные
RU gates. Host template показывает control и разблокирует store только
под `#if DEBUG`; в Release default store принудительно возвращает `.followAdapty`.

## Последствия

Положительные:

- Special Offer работает через стандартный Adapty repository;
- покупка сохраняет точную raw product reference и attribution;
- `ru_pay` не ослабляется до provider cache ради достижимости Special Offer;
- собственный persistent cache платформы не включает чувствительные функции;
- защита premium-доступа не ослабляется.

Ограничение: provider-managed cache может на короткое время сохранить прошлый
`special_offer = true`. Это принято для нефинансового визуального downsell, но не для RU Billing.

## Проверка решения

Контракт закреплён обязательной командой:

```bash
bash Scripts/check_remote_feature_contracts.sh
```

Она проверяет provenance matrix, `false` kill switch, запрет восстановления
старых gates, downgrade platform cache, сохранение product registry и отсутствие
custom Adapty REST/второго experiment randomizer. Команда входит в полный
`Scripts/agent_gate.sh`.
