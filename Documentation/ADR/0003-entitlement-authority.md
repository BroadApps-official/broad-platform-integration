# ADR-0003: Authoritative entitlement после оплаты

- Статус: принято
- Дата: 2026-08-09

## Контекст

Приложение может получать premium из Apple, основного backend и RU billing. Сетевые ошибки, SDK cache и непроверенные transaction не доказывают отсутствие доступа. Одновременно успешный checkout не доказывает, что backend/StoreKit уже признал entitlement active.

Binary `isPremium` и правило «последний ответ победил» создают два опасных исхода:

- ложный отзыв доступа при timeout/offline;
- ложная выдача доступа сразу после непроверенной оплаты.

## Решение

Использовать три состояния:

- `active` — authoritative source подтвердил доступ;
- `inactive` — все настроенные authoritative sources пригодны и явно подтвердили отсутствие доступа;
- `unresolved` — результат нельзя доказать из-за timeout/offline/auth/decoding/unverified freshness.

Агрегация:

```text
любой qualified active → active
все configured sources inactive → inactive
любая оставшаяся неопределённость → unresolved
```

Настраиваются три logical sources:

- `.apple` — один composite source из StoreKit и optional qualified verifiers;
- `.primaryBackend` — текущий server response exact subject;
- `.ruBilling` — только для enabled/fully configured RU backend.

Два Apple verifier не регистрируются как две независимые authority: они объединяются внутри одного `.apple` repository и одного cache assertion.

После любого raw purchase/restore/RU payment completion выполняется:

```text
refreshEntitlement(policy: .startNewGeneration)
```

Только итоговый `.active` возвращает `.activated/.restored` и разрешает `AppFlowCoordinator.subscriptionDidBecomeActive()`.

`pending`, `cancelled`, SDK success + unresolved, открытая payment page и payment status без active entitlement доступ не выдают.

## Freshness и cache

- каждый source имеет конечный TTL;
- optional offline grace применим только к предыдущему active;
- inactive не продлевается произвольным offline grace;
- cache scoped по source + anonymous/opaque subject fingerprint;
- raw user ID/profile/token не сохраняются;
- concurrent refresh одного policy объединяется single-flight;
- новый generation отменяет логическую актуальность старого;
- late result после deadline не меняет snapshot и cache.

Обычный cached Adapty profile без доказуемого `fetchedAt/serverValidated` считается unqualified и не выдаёт fresh active/inactive.

## Последствия

Положительные:

- timeout не превращается в ложный inactive;
- SDK completion не превращается в ложный premium;
- Apple/backend/RU могут мигрировать независимо;
- AppFlow получает единый безопасный status;
- offline behavior задаётся явной policy.

Цена решения:

- purchase может закончиться `completedButUnverified`;
- UI должен объяснять pending/unavailable без закрытия paywall;
- source adapters обязаны точно классифицировать freshness;
- host хранит append-only список текущих и исторических Apple premium SKU.

## Отклонённые варианты

### SDK purchase success сразу открывает premium

Отклонён: transaction/backend entitlement может быть pending, unverified или относиться не к ожидаемому subject.

### Любая ошибка означает inactive

Отклонён: лишает платящего пользователя доступа при временном сбое.

### Любой cached active бессрочно побеждает

Отклонён: revoked/expired entitlement никогда не обновится.

### Adapty и StoreKit как независимые logical Apple sources

Отклонён: дублирует одну authority, ломает cache scope и может неверно требовать inactive от двух представлений одного магазина.

## Проверка решения

Ручная матрица включает:

- active + inactive → active;
- active + unresolved → active;
- все inactive → inactive;
- inactive + unresolved → unresolved;
- unverified transaction → unresolved;
- timeout + late active → unresolved без поздней смены route/cache;
- restore inactive → nothing found;
- SDK complete + unresolved → completedButUnverified;
- RU source отсутствует при disabled feature.

Подробная модель и fixtures: [Entitlements](../Entitlements.md). Исходник схемы: [entitlement-authority.mmd](../Diagrams/entitlement-authority.mmd).
