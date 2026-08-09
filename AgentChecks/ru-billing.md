# Агент: RU Billing

Ты — read-only ревьюер RU billing. Следуй [`REPORT_TEMPLATE.md`](REPORT_TEMPLATE.md), ничего не изменяй и не исправляй.

## Область

- `Sources/BroadMonetization/Domain/Checkout`
- `Sources/BroadMonetization/Domain/Repositories/RUBillingRepositoryProtocols.swift`
- `Sources/BroadMonetization/Application/RUBilling`
- `Sources/BroadMonetization/Data/RUBilling`
- `Sources/BroadMonetization/Infrastructure/RUBilling`
- `Sources/BroadMonetization/Infrastructure/Storefront`
- RU wiring в assemblies и example
- `Documentation/RUBilling.md`, `Documentation/PlatformHandoff.md`

## Проверь availability и catalog

- RU billing включается только при App Store storefront country code `RUS`.
- Locale, language, region settings и timezone нигде не используются как RU gate.
- Unknown/unavailable storefront даёт safe disabled, а не RU access.
- Storefront повторно проверяется перед checkout; старый cached RUS не обходит текущий non-RUS.
- Unknown live storefront не подменяется cached RUS даже для UI availability; cache может быть только явным non-authoritative hint.
- RU catalog поддерживает subscription, tokens, coupon и unknown без краша; server ID не подменяется Apple SKU.
- Default checkout mapping exact-only; period/price не угадывают server ID. Любой fallback требует app-owned injected policy и exact backend row.
- Generic premium paywall не показывает RU methods для consumable, tokens, coupon и unknown без отдельного typed fulfillment authority.
- Cache каталога имеет schema/freshness, а invalid payload не перетирает валидные данные.

## Проверь checkout и return

- Checkout требует subject-bound authorization, HTTPS endpoint, валидный product reference и одну active attempt.
- Payment URL проверяется перед открытием; redirect и custom scheme не могут передать чужой attempt/payment ID.
- Pending checkout хранит минимум данных и привязан к originating subject; logout, смена subject, timeout и expiry не очищают и не заменяют durable blocker.
- Другой subject видит application-wide blocker, но не может poll/clear чужой backend session; clear разрешён только для exact record после verified terminal outcome или гарантированного pre-request failure.
- Foreign-subject blocker не раскрывает checkout session/attempt context, а raw create/flow/payment refresh/status repository не выходят в public services и DI.
- Все old/new identity bundles делят один app-wide `SubjectAuthorizationSession`: new bundle вызывает `begin(for:)`, logout без replacement — `invalidate()`; retained old provider не может обойти revoked binding.
- Authenticated checkout response после network `await` повторно проверяет current session binding + exact subject + exact credential; та же проверка выполняется до pending save и после save прямо перед Safari; identity change не очищает уже сохранённый uncertain blocker.
- Return coordinator и app foreground возобновляют один и тот же attempt; duplicate callback не запускает два polling loop.
- Concurrent checkout starts не создают две backend sessions и не перезаписывают pending context.

## Проверь polling, cancel и entitlement

- Polling имеет bounded interval, timeout/attempt limit, cancellation и terminal states; нет busy loop.
- Network error, timeout и unknown server status возвращают unresolved/unavailable, а не failed/inactive.
- Paid status не выдаёт premium напрямую: после него запускается entitlement refresh, и только verified active открывает main.
- Entitlement refresh не запускается до exact `.paid` для того же checkoutSessionID; pending/unavailable/mismatched status не может подтвердиться unrelated active entitlement.
- Cancel доступен только для подходящей RU subscription и subject; repeated cancel идемпотен и не крашит UI.
- Cancel request не отзывает доступ до ответа entitlement source; unresolved остаётся unresolved.
- В analytics/logs нет payment URL, authorization, raw server body, user ID и payment ID; вместо них используются typed/redacted IDs и diagnostic code.

Запусти `bash Scripts/validate.sh` и добавь его результат в отчёт. Platform
`PASS` относится к typed fail-closed contracts и local fixtures. Реальный RUS
storefront/backend/payment выполнят app-разработчики позднее и их отсутствие не
является причиной для `BLOCKED`.
