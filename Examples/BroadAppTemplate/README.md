# BroadAppTemplate

`BroadAppTemplate` — запускаемый пример инженерной основы нового приложения. Он
показывает разработчику правильную структуру, рабочий composition root,
маршрутизацию и fixture-состояния. Новое приложение строится поверх тех же
модулей платформы, а демонстрационный UI заменяется экранами конкретного бренда.

Reference-проект — это готовое похожее приложение коллеги из Git-репозитория
компании. Разработчик сначала ищет его в Kaiten и Git компании, а если не может
однозначно выбрать — запрашивает reference у тимлида-разработчика или
проектного менеджера. Из него изучаются экраны, поведение, тексты, временные
app-owned данные и backend-контракты, но не архитектура. Все функции нового
проекта нужно сопоставить с реальными API-ручками reference; отсутствующую или
недостаточную ручку сначала обсуждают с тимлидом-разработчиком или проектным
менеджером. Источник дизайна определяется только меткой карточки Kaiten:
`no-code` ведёт к согласованному Claude Design/Pencil, а без этой метки
обязательна Figma. Пустое поле или недоступная ссылка Figma не превращают проект
в `no-code`: нужно запросить доступ или экспорт у ПМ.
Внешний вид RU-оплаты сверяйте с
[описанием полного RU Billing flow](../../README.md#visual-reference).

Usedesk намеренно не встроен в example target: готовый UI этого SDK
устанавливается через CocoaPods и нужен не каждому приложению. В рабочем
приложении вход добавляется отдельной строкой `Настройки → Онлайн-чат`, а user
chat token хранится через backend app account. [Инструкция Usedesk с Podfile и
готовым промптом →](../../Documentation/Usedesk.md).

> Example предназначен только для iPhone и генерируется с
> `TARGETED_DEVICE_FAMILY = 1`. iPad, Mac, Mac Catalyst и visionOS не входят в
> platform scope.

Example показывает полный локальный flow платформы:

```text
launch → configurable onboarding → initial paywall policy → optional special offer → main
                                                        verified active ───────→ premium
```

`main` и premium — не одно состояние. Разрешённое закрытие paywall,
недоступный каталог или `unknown` entitlement могут открыть обычный `main`, но
premium-возможности внутри него открывает только подтверждённый `active`.

Обычный запуск показывает три страницы только как короткий пример. Их число не
зашито в платформу: `ExampleOnboardingScenario.pages` формирует массив, а
`BroadUIFlows` берёт длину только из него.

## Запуск

Из корня `BroadAppsIOSPlatform`:

```bash
./Scripts/generate_example.sh
open Examples/BroadAppTemplate/BroadAppTemplate.xcodeproj
```

Выберите схему `BroadAppTemplate` и iOS Simulator. Progress сохраняется; чтобы увидеть чистый first run повторно, удалите приложение из Simulator.

Полная проверка package + example:

```bash
./Scripts/lint.sh
./Scripts/build.sh
```

## Что демонстрирует example

- интерактивный каталог из девяти работающих карточек: app flow, subscription
  paywall, token paywall, special offer, RU Billing, loader/error, analytics,
  Contact Us и Debug-хранилища;
- три initial-paywall policy: once, every cold launch while inactive и disabled;
- special offer как опциональную ветку после закрытия subscription paywall;
- отдельный consumable token paywall с backend-confirmed balance, pending,
  идемпотентным retry, offline и account recovery fixture;
- независимую очистку Keychain, app-flow progress, content cache и in-memory
  analytics с результатом рядом со своей кнопкой;
- composition root и порядок `Core → Monetization → UIFlows`;
- onboarding из любого количества страниц без отдельного `slidesCount`;
- готовый `BroadOnboardingView` и полностью app-owned UI через
  `BroadOnboardingFlowHost`;
- ATT только после появления первого слайда;
- отсутствие ATT при `-onboarding-disabled` и безопасном invalid-flow;
- paywall для 0, 1 и любого количества продуктов без фильтрации;
- product tap/purchase без opacity/scale/dimming;
- purchase/restore с обязательным fresh entitlement;
- один shared non-blocking → deduplicating → composite analytics pipeline;
- bounded typed recorder и debug-панель без PII/raw SDK data;
- bootstrap/cache/timeout fixtures;
- технический RU payment fixture без endpoint и реального списания;
- экран RU subscription management до и после отмены;
- safe disabled production RU adapter без fake endpoint/token/`.ruBilling` source.

Example использует локальные monetization fixtures и
`DisabledRUBillingCheckoutMethodsUseCase` для production boundary. Отдельные RU
launch arguments показывают настоящий platform UI, но не отправляют запросы и
не выполняют списания.

Переустановку нельзя честно сымитировать только локальным fixture: token balance и
RU purchases обязаны вернуться из backend того же app account. Готовый
platform-координатор и обязательный backend contract описаны в
[Account Recovery](../../Documentation/AccountRecovery.md). Поведение при обрыве связи
во время любого шага зафиксировано в
[Network Interruptions](../../Documentation/NetworkInterruptions.md).

Для real-catalog smoke доступны две готовые схемы:

- `BroadAppTemplateLiveAdapty5013`;
- `BroadAppTemplateLiveAdapty5109Codex`.

Рабочие bundle/Adapty/placement values хранятся в соответствующих tracked
`.xcconfig`. Дополнительный импорт перед запуском не нужен.

Reference repositories остаются read-only. Live scheme проверяет только Adapty
activation/load/show. StoreKit purchase и restore запрещены company policy и
fail-before-charge.

## Полезные launch arguments

Обычные fixture-экраны лучше открывать кнопками из каталога приложения: им не
нужен перезапуск. Аргументы ниже предназначены для cold-launch поведения, потому
что читаются при создании процесса. В Xcode откройте
`Scheme → Edit Scheme → Run → Arguments`, добавьте один аргумент из выбранной
взаимоисключающей группы и полностью перезапустите приложение. В Debug-настройках
каждый поддерживаемый аргумент можно скопировать; рядом указаны назначение и
ожидаемый результат.

| Аргумент | Сценарий |
|---|---|
| `-app-flow-main-only` | только main |
| `-app-flow-paywall-only` | paywall без onboarding |
| `-initial-paywall-disabled` | initial paywall автоматически не показывается |
| `-initial-paywall-every-cold-launch` | при подтверждённом inactive paywall возвращается после каждого cold launch, но не повторяется в той же сессии |
| `-live-adapty` | настоящий каталог Adapty; финансовые вызовы отключены |
| `-analytics-fixture` | только paywall и безопасная локальная запись событий аналитики |
| `-tracking-disabled` | полная проверка UI без системного окна ATT |
| `-onboarding-one-page` | стандартный onboarding из одной страницы |
| `-onboarding-two-pages` | стандартный onboarding из двух страниц |
| `-onboarding-three-pages` | явный пример из трёх страниц |
| `-onboarding-four-pages` | стандартный onboarding из четырёх страниц |
| `-onboarding-long` | восемь страниц, динамический progress и scroll |
| `-onboarding-custom-ui` | четыре страницы в полностью своём SwiftUI через logic-only host |
| `-onboarding-disabled` | маршрут onboarding штатно отключён |
| `-onboarding-invalid` | пустая ошибочная конфигурация безопасно завершается без UI и ATT |
| `-paywall-empty` | paywall без продуктов |
| `-paywall-one-product` | один продукт выбирается автоматически |
| `-paywall-two-products` | два продукта сохраняют порядок провайдера |
| `-paywall-many-products` | 12 продуктов и всегда доступные нижние кнопки |
| `-paywall-payment-methods` | только UI выбора Apple/СБП/карты; настоящий RU-адаптер отключён |
| `-special-offer-enabled` | текущий ответ Adapty содержит `special_offer = true`: кампания открывается |
| `-special-offer-disabled` | явный `special_offer = false`: кампания остаётся закрытой |
| `-special-offer-platform-cache` | кеш `BroadMonetization` содержит `true`, но кампания остаётся закрытой |
| `-special-offer-main-fallback` | placement кампании недоступен; Remote Config резервного `main` открывает её и сохраняет исходный placement |
| `-special-offer-timed` | кампания с фиксированным доверенным серверным временем и таймером на три минуты |
| `-ru-pay-provider-enabled` | текущий ответ Adapty содержит `ru_pay = true`, а российский контекст iPhone показывает Apple/СБП/карту |
| `-ru-pay-platform-cache` | `ru_pay = true` из кеша `BroadMonetization` отклоняется; остаётся только Apple |
| `-ru-payment-sheet` | технический СБП fixture: две обязательные галочки, чек и сохранённый email; без отдельных строк legal links |
| `-ru-payment-sheet-apple` | Apple выбран; RU consent/receipt поля отсутствуют |
| `-ru-subscription-management` | активная RU подписка, дата и действие отмены |
| `-ru-subscription-cancelled` | подписка активна до даты, автопродление отключено |
| `-paywall-failure` | safe load error |
| `-paywall-hard` | hard access policy |
| `-token-paywall-main-fallback` | `.tokens` недоступен; token UI принимает резервный `main` только с consumable-продуктами и не превращается в subscription paywall |
| `-purchase-cancelled` | user cancellation |
| `-purchase-pending` | pending без premium |
| `-purchase-failure` | safe purchase error |
| `-restore-nothing` | restore without active access |
| `-restore-failure` | safe restore error |
| `-entitlement-active` | verified active |
| `-entitlement-inactive` | all configured verifiers inactive |
| `-entitlement-unknown` | unresolved без ложного premium |
| `-entitlement-store-kit-fallback` | StoreKit active при unqualified Adapty cache |
| `-entitlement-timeout` | late active игнорируется после deadline |
| `-bootstrap-degraded` | background timeout, main доступен |
| `-bootstrap-failed-once` | critical failure → manual retry |
| `-bootstrap-seed-cache` | записать stale-cache fixture |
| `-bootstrap-stale-cache` | offline fallback после seed |

### Проверка Special Offer и `ru_pay`

Эти семь сценариев проверяют не нарисованный экран, а настоящий контракт
`BroadMonetization`. Special Offer проходит через `ResolveSpecialOfferUseCase`,
а RU methods — через `ResolveCheckoutMethodsUseCase` и `RUBillingGate`.

Для Special Offer результат виден сразу: разрешённая кампания открывает общий
paywall, заблокированная показывает безопасное объяснение. Для RU-сценария
выберите продукт и нажмите `Продолжить`: у текущего ответа Adapty появятся
Apple/СБП/карта, у сохранённой копии из кеша `BroadMonetization` останется только
Apple.

В консоли Xcode появляется безопасная typed-запись
`remote-feature.fixture.resolved` со сценарием, итогом, логическими
requested/resolved placement, наличием variation и источником данных. Так можно
проверить резерв на `main` без настоящего платежа, произвольных строк в OSLog и
доступа к Adapty Dashboard.

## Analytics fixture

Запустите example с `-analytics-fixture -tracking-disabled`, выберите продукт и
закройте safe paywall — настоящая покупка для создания событий не нужна. На
main откройте карточку `Аналитика` либо кнопку с инструментами, затем нажмите
`Обновить события` (или используйте pull-to-refresh). В списке показываются
только typed safe fields: attempt/presentation, logical placement, SKU,
variation, checkout method и safe diagnostic code.

Сценарии `-purchase-pending`, `-purchase-cancelled`, `-purchase-failure` и
`-restore-nothing` позволяют проверить разные terminal events. Кнопка
`Очистить события` очищает только bounded in-memory историю и сразу показывает
число удалённых записей.

[Полный analytics contract и ожидаемая последовательность →](../../Documentation/Analytics.md)

Подробный quick start, ожидаемые результаты и команды `simctl`: [корневой README](../../README.md#example-и-ручные-сценарии).
