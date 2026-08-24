# Security и privacy guide

Платформа построена так, чтобы UI и Domain физически не могли получить большинство секретных SDK/backend деталей. Но безопасность production-приложения всё равно зависит от app-owned configuration, backend и выбранных analytics destinations.

## Короткие правила

1. Tracked reference configs могут хранить client-visible Adapty public SDK key;
   bearer, private keys, URL оплаты и пользовательские данные в Git не кладутся.
2. Не логируйте raw `Error`, request/response body, SDK profile и arbitrary metadata.
3. Не выдавайте premium по факту успешного checkout — только по authoritative entitlement `.active`.
4. RU Billing требует `ru_pay = true` из `.verifiedFreshRemote` payload;
   дополнительно достаточно RU-региона iPhone или русского первого системного
   языка. Собственный cache платформы, IP и timezone не авторизуют RU methods.
5. Не кешируйте credentials в `UserDefaults`/`CacheRepositoryProtocol`.
6. ATT вызывается только после видимого первого onboarding-слайда; Rate Us внутри onboarding запрещён.
7. Apple purchase/restore/RU используют один app-wide gate и durable pending state.
8. Premium/token/RU ownership хранится у StoreKit/backend, а не в install-local
   flags или balance.
9. Событие «сеть снова доступна» не разрешает автоматически повторять charge;
   сначала выполняется reconciliation.
10. Usedesk API token не помещается в приложение; backend app account хранит
    основной user chat token, account-scoped Keychain — только cache/pending
    sync, а device ID не заменяет identity пользователя.
11. Support email может показать ID в системной форме только после действия
    пользователя; support log не содержит токены, payment URL и raw payload.
12. После изменения платформы запускайте полный `agent_gate.sh`.

## Классы данных

| Класс | Примеры | Можно хранить/логировать платформой? |
|---|---|---|
| Client configuration | Adapty public SDK key, bundle, placements | разрешено в tracked reference configs |
| Backend secret | bearer, refresh token, signing/private key | нет |
| PII | email, raw user/customer ID, receipt fields | не логировать и не коммитить; receipt email можно хранить только как явно выбранную локальную UI-настройку |
| Sensitive URL | checkout/payment URL с параметрами | нельзя логировать/кешировать |
| Opaque identity | subject fingerprint | только scoped entitlement cache |
| Safe diagnostics | typed error kind, diagnostic code, counters | да |
| Catalog metadata | logical placement, product ID, product count | только через typed analytics policy |
| Usedesk chat identity | user chat token, имя, email, телефон, `additional_id` | не логировать; backend app account — источник, Keychain — account-scoped cache/pending sync |

Product ID может раскрывать внутреннюю структуру каталога. Он разрешён в typed monetization analytics, но destination приложения должен применять собственную data-retention policy.

## Tracked Adapty reference configurations

Example намеренно содержит две рабочие client-конфигурации:

- Adapty public SDK key;
- bundle ID, access level и placements для live catalog smoke.

Эти client-visible значения являются частью Git/source digest. Public SDK key
уже присутствует в клиентском приложении и не используется как backend
authorization credential.

Package по-прежнему не содержит:

- backend host и authorization token;
- payment/cancellation URL;
- private keys, provisioning profiles и environment-файлы.

Host получает secrets из своей защищённой runtime/build configuration. Для долговременного client-side хранения используйте Keychain-backed app adapter. В platform cache и app-flow state store секреты класть нельзя.

Для новых приложений app-команда либо добавляет согласованный tracked client
config, либо передаёт его из своей build configuration. Backend credentials в
эти `.xcconfig` добавлять нельзя.

## Очистка Keychain в Debug

Во время разработки разрешена отдельная кнопка
`Настройки → Debug-настройки → Очистить Keychain`. Используйте готовый
`DebugKeychainCleaner` из `BroadAppTemplate`: он существует только под `#if DEBUG` и принимает
точные app-owned `service` и, при необходимости, `accessGroup`.

Запрещено удалять весь класс Keychain без scope, показывать кнопку в Release или
вместе с credential очищать Apple/RU/token pending-записи. Pending — отдельная
защита от повторной финансовой операции. Подключение и готовый UI-flow описаны в
[Debug и async-действиях](DebugToolsAndAsyncActions.md).

## Subject-bound authorization

Backend adapters получают credential через `SubjectAuthorizationProviderProtocol`. Результат содержит `SubjectBoundAuthorization`, который:

- жёстко связан с ожидаемым `EntitlementSubject`;
- валидирует bearer как однострочное RFC-compatible значение;
- ограничивает размер;
- не раскрывает значение через `description`, debug description или reflection;
- остаётся transient и не сохраняется платформой.

Если provider вернул token для другого subject, запрос не должен отправляться. Одна повторная проверка provider недостаточна: старая task может удерживать старый immutable provider. Поэтому все RU identity bundles используют bindings из одного app-wide `SubjectAuthorizationSession`. Новый bundle вызывает `begin(for:)`, logout — `invalidate()`.

После каждого успешного RU HTTP response platform принимает response только при current session binding + exact subject + exact credential match. Checkout повторяет ту же проверку до сохранения pending и после этого `await` прямо перед Safari. Смена identity не может принять старый response; если pending уже успел сохраниться, он остаётся blocker-ом и не очищается по logout.

Смена пользователя требует новой composition/identity preparation и очистки app-owned user state по migration policy. `SubjectAuthorizationSession` при этом не пересоздаётся: это общий revocation boundary между старым и новым bundle.

Никогда не передавайте credential через query string, analytics property, error message или cache key.

Для Usedesk различайте секретный API token и user chat token переписки. Для
обычного мобильного чата `api_token` должен быть `nil`. Backend текущего
авторизованного пользователя — основной источник user chat token. Callback
сначала сохраняйте в account-scoped Keychain, затем синхронизируйте с backend;
временная ошибка оставляет durable pending sync и не проглатывается через
`try?`. Cache другого аккаунта недоступен, device ID не используется как
identity. Установите `isSaveTokensInUserDefaults: false`.
[Usedesk →](Usedesk.md).

После переустановки server state можно вернуть только после доказанного login в
тот же app account. Anonymous subject допустим для Apple ownership policy
`.appStoreAccount`, но не даёт безопасной связи с token balance текущего app
account или RU customer.
Не подменяйте identity device ID, locale, receipt email или новым случайным ID
каждой установки. [Account Recovery →](AccountRecovery.md).

## HTTP boundary

Production URLSession adapters используют консервативные правила:

- только HTTPS;
- URL без embedded username/password;
- redirect запрещён;
- ephemeral session;
- cookies и shared credential storage отключены;
- URL cache отключён;
- response body имеет конечный maximum size;
- принимается только ожидаемый success status;
- decoding проверяет subject, bundle/application identity и непротиворечивые даты;
- raw response body и raw error не выходят в Domain/UI/log.

Backend с другой схемой реализует свой encoder/decoder protocol на Infrastructure-границе. Ослаблять Domain или передавать wire DTO в Presentation не нужно.

Для RU checkout дополнительно:

- payment URL валидируется как HTTPS до открытия;
- redirect и legacy cancellation fallback не включаются неявно;
- pending context не содержит URL, email, bearer или raw identity;
- receipt email живёт отдельно от pending context под app-owned key, только
  после явного выбора пользователя; в analytics/log/cache envelope не попадает;
- возвращение из Safari не считается оплатой без нового server status + entitlement refresh.

[Primary backend entitlement →](Entitlements.md#основной-broadapps-backend) · [RU HTTP contract →](RUBilling.md#http-configuration-and-authorization)

## Entitlement safety

Главная инварианта:

```text
checkout completed ≠ premium active
```

`special_offer = true` и `ru_pay = true` тоже не равны premium. Первый разрешает
второй paywall из provider payload; второй ещё и требует verified freshness.
Purchase/restore/RU return в любом случае обязаны завершиться новой
authoritative entitlement-проверкой.

После purchase/restore/RU return запускается `refreshEntitlement(policy: .startNewGeneration)`. Доступ открывает только итоговый `.active`.

Engine не превращает следующие ситуации в inactive или active:

- network timeout/offline;
- decoding/authorization error;
- unverified StoreKit transaction;
- unqualified Adapty cached profile;
- late response после generation deadline;
- открытая внешняя страница оплаты;
- payment status paid без подтверждённого entitlement;
- отсутствующий optional source.

`inactive` возможен только когда **каждый настроенный** source явно подтвердил inactive. Отключённый RU backend не добавляется как unresolved registration.

Entitlement cache:

- scoped по logical source и anonymous/opaque subject fingerprint;
- имеет конечный TTL;
- offline grace применяет только к прежнему active;
- не сохраняет raw user ID/token/profile;
- не принимает late result истёкшей generation;
- для RU хранит logical authorization epoch в одном bounded
  physical slot на subject/source: новый binding exact-отклоняет
  late record старой session и не получает cached active.

[Entitlement threat model →](Entitlements.md) · [ADR →](ADR/0003-entitlement-authority.md)

## Durable payment safety

До открытия Apple purchase sheet platform атомарно пишет
`PendingApplePurchaseStore`; до открытия RU payment URL —
`PendingRUCheckoutStore`. Оба используют один app-wide
`MonetizationOperationGate`, общий для всех экранов и login identities.

- Apple Ask-to-Buy и provider error с неизвестным исходом остаются `.pending`;
- verified StoreKit bridge принимает только current bundle, reason `.purchase`,
  подходящую ownership policy, не-revoked и не-upgraded transaction;
- bridge запускается до Adapty activation и не вызывает `finish()`;
- foreground recovery проверяет history на launch/active;
- application-wide record хранит opaque originating subject;
- begin/phase/clear используют atomic insert/compare-and-set/remove;
- unreadable/corrupt state блокирует второй charge fail-closed;
- logout, timeout и смена composition не очищают pending payment.

User acknowledgement, review boundary и fresh inactive не доказывают отмену
Ask-to-Buy/outcome-unknown и никогда не очищают durable record. Deprecated
`abandonAfterUserConfirmation()` только повторяет reconciliation. Blocker снимает
лишь definitive provider cancellation/failure до покупки либо verified terminal
reconciliation; premium product дополнительно ждёт authoritative entitlement.
Никогда не добавляйте «очистить pending» в UI или launch recovery.

Token flow хранит отдельный `PendingTokenPurchaseStore`. До StoreKit sheet в нём
находится только intent, а после verified transaction — подписанный StoreKit JWS,
необходимый для идемпотентной backend-выдачи токенов. Такой record:

- хранится только в app-owned durable store с ограниченным scope;
- не попадает в логи, analytics, crash metadata и общий paywall cache;
- очищается только после authoritative fulfillment/rejection;
- восстанавливается на launch/foreground и блокирует повторную оплату;
- не используется клиентом для самостоятельного изменения token balance.

## Logging

`BroadLoggerProtocol` принимает закрытый `BroadLogEvent`, а не строку или dictionary. Поэтому caller не может случайно отправить payload.

Запрещено:

- `print`, `debugPrint`, `dump`, `NSLog`;
- legacy `os_log` и произвольный signpost;
- raw `localizedDescription`;
- request/response body;
- cache key/schema/namespace, если они содержат app/user context;
- email, user/customer ID, bearer, payment URL;
- Adapty profile или StoreKit transaction object.

`OSLogBroadLogger` — единственный разрешённый OSLog adapter. Без явной настройки используется `NoOpBroadLogger`.

[Typed logging contract →](Logging.md)

## Analytics

`MonetizationAnalyticsEvent` передаёт только typed контексты. RU analytics специально исключает:

- email;
- checkout session ID;
- payment URL;
- bearer;
- user identity.

Для анализа внешней RU-конверсии разрешены только безопасные catalog/paywall
идентификаторы: app-generated presentation ID, opaque Adapty variation и
requested/resolved logical placement. Они сохраняются в pending context для
cold-launch continuation, но не отправляются в RU billing HTTP request. Raw
Adapty paywall/product, SDK profile и commercial fingerprint в analytics не
попадают.

Ошибки представлены `AppError.Kind + diagnosticCode`, без raw text. Attempt ID генерируется приложением для одной операции и не содержит provider transaction/user ID.

`DeduplicatingMonetizationAnalytics` резервирует lifecycle key до первого `await`, чтобы concurrent вызовы не создавали двойные impression/purchase events. Ограниченный retention предотвращает бесконечный рост памяти.

App analytics destination обязан отдельно проверить:

- список разрешённых событий/полей;
- consent requirements;
- retention и export policy;
- отсутствие автоматического screen/payload collection.

## Cache и persistence

`CacheRepositoryProtocol` подходит только для небольших несекретных Codable snapshots. `UserDefaultsKeyValueStore` даёт actor isolation и namespace, но не является secret storage.

Не сохраняйте в общий cache:

- API/bearer/refresh token;
- payment URL;
- receipt email; готовый RU payment UI хранит его отдельно как bounded
  app-owned form preference, не как финансовый или entitlement snapshot;
- raw user/customer ID;
- SDK profile/transaction;
- signed StoreKit JWS, кроме scoped `PendingTokenPurchaseStore` до завершения
  idempotent token fulfillment;
- private remote payload с PII.

AppFlow progress хранит только монотонные checkpoints. Premium status туда не записывается. Special-offer persistence хранит только typed lifecycle state и app config fingerprint, а не paywall payload/identity.

После удаления приложения все platform records могут исчезнуть. Backend обязан
идемпотентно хранить Apple/RU purchase ledger и authoritative token balance;
StoreKit/backend entitlement заново проверяется при login. Локальный cache не
является disaster-recovery механизмом.

При logout/switch account host обязан:

1. сменить entitlement subject;
2. очистить user-scoped host caches;
3. подготовить SDK identity для нового subject;
4. пересобрать subject-bound Apple/RU stores поверх того же app-wide cache,
   `applicationIdentifier` и `MonetizationOperationGate`;
5. вызвать `SubjectAuthorizationSession.begin(for:)` для нового
   bundle; при logout без replacement вызвать `invalidate()`;
6. не poll/reconcile/clear pending Apple/RU record другого subject, сохраняя его
   как blocker;
7. запустить fresh entitlement generation.

## ATT и review privacy

ATT adapter импортирует `AppTrackingTransparency` в одном Infrastructure-файле. Системный prompt разрешён только если:

- первый onboarding-слайд фактически появился;
- он остаётся текущим;
- scene active;
- view находится в видимом window;
- прошла app-configured delay;
- status `.notDetermined`.

Loader/bootstrap/AppFlow не вызывают ATT. Default policy — `.disabled`.

Rate Us/review не является частью tracking consent. Он разрешён вне onboarding, но внутри onboarding отсутствует полностью. [ADR →](ADR/0002-att-and-rate-us.md).

## Privacy manifest

`BroadCore` сам хранит небольшие typed state/cache snapshots через
`UserDefaultsKeyValueStore`; это не чистый wrapper над вызовами host app. Поэтому
package включает [BroadCore privacy manifest](../Sources/BroadCore/Resources/PrivacyInfo.xcprivacy) с:

- `NSPrivacyAccessedAPICategoryUserDefaults`;
- approved reason `CA92.1` для app-only state/cache в `UserDefaults.standard`;
- approved reason `1C8F.1`, когда host явно передаёт suite той же App Group для
  app и его extensions;
- `NSPrivacyTracking = false`;
- пустыми collected-data и tracking-domain arrays.

`C56D.1` не заявляется: BroadCore использует storage для собственного
state/cache, а не только предоставляет wrapper другому коду. Host обязан выбирать
suite и способ использования, соответствующие заявленным reasons. Определения и
ограничения reasons сверяйте с официальной документацией Apple:
[Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).

Manifest описывает только саму платформу. Host app и его остальные SDK отдельно декларируют свои required-reason APIs, collected data и tracking domains. `check_privacy_manifest.sh` проверяет plist, точный набор category/reasons и наличие именно BroadCore manifest в Release `iphoneos` app; чужой manifest Adapty/Swinject не считается заменой.

## Adapty privacy settings

`AdaptyPlatformConfiguration` по умолчанию создаётся с `idfaCollectionDisabled: true`. Это не заменяет app-level privacy review. Host отдельно решает:

- включать ли ATT policy;
- разрешать ли IP collection (`ipAddressCollectionDisabled`);
- нужен ли observer mode;
- как и когда назначать customer identity;
- какие analytics destinations активировать после consent.

API key и customer identity redacted в строковом представлении. Но это не даёт права передавать объект в сторонний generic logger.

## Автоматические проверки

```bash
./Scripts/lint.sh
```

Включает:

- SwiftLint rules для SDK/import/DI границ;
- запрет ATT API вне canonical adapter;
- запрет review API внутри onboarding и вне dedicated review adapter;
- запрет console/raw-error logging;
- запрет hardcoded paywall price/SKU в Presentation;

```bash
./Scripts/release_gate.sh
```

Проверяет exact tool versions, format/lint/architecture rules, privacy source, package с `strict-concurrency=complete` + `warnings-as-errors`, Debug/Release Simulator и unsigned Release `iphoneos`. Device product обязан содержать BroadCore privacy manifest. Test targets не используются.

Для полной проверки после изменения платформы используйте
`bash Scripts/agent_gate.sh`: он добавляет документацию и обе live Adapty
configurations. Короткий порядок действий описан в
[checklist перед передачей изменений](PlatformHandoff.md).

## Ручной security checklist

- [ ] в repo нет реальных secrets, PII, payment URL и private files;
- [ ] runtime configuration не попадает в description/debug/log;
- [ ] authorization provider проверяет exact subject;
- [ ] HTTP base URL HTTPS и без credentials/query secrets;
- [ ] redirects/cookies/cache отключены;
- [ ] response size ограничен;
- [ ] raw backend/SDK errors заменены safe `AppError`;
- [ ] purchase/restore/RU return не открывают premium до active snapshot;
- [ ] late entitlement response не меняет route/cache;
- [ ] anonymous и authorized cache scopes разделены;
- [ ] logout очищает user-scoped host state;
- [ ] RU eligibility требует verified-fresh `ru_pay = true` и RU region или русский первый системный язык;
- [ ] ATT отсутствует в loader и вызывается после visible first slide;
- [ ] review отсутствует внутри onboarding;
- [ ] Console не содержит token, IDs, URL, payload и user messages;
- [ ] analytics export проверен на лишние поля;
- [ ] `lint.sh` и `build.sh` проходят.
