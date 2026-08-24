# Приёмка BroadAppTemplate

Эта таблица описывает ожидаемое поведение example-приложения. Она
нужна для ручной проверки на iPhone Simulator без настоящих платежей.

## Как читать таблицу

- **Действие** — что нажать или как запустить сценарий.
- **UI** — что обязан увидеть разработчик.
- **Диагностика** — видимый результат и, где он полезен, безопасный typed OSLog
  без ключей, токенов и raw payload. Console не заменяет UI.
- **Сохраняется** — какое состояние переживает повторный запуск.
- **Нельзя** — граница, которую сценарий не имеет права нарушать.

## Где закрыты все 16 шагов плана

| Шаг | Реализация | Доказательство |
|---:|---|---|
| 1 | Эта acceptance-таблица и отдельные строки замечаний ревью | Ниже есть действие, UI, диагностика, persistence и запрет для каждого сценария |
| 2 | `ExampleMainView` + `RootView` | Девять нажимаемых карточек, возврат через общий full-screen catalog |
| 3 | `ExampleDebugScenariosView` + `ExampleDebugSettingsViewModel` | Четыре независимых scope, confirmation там, где он нужен, inline count/result |
| 4 | `AppFlowInitialPaywallPolicy` + `AppFlowStateMachine` | `once`, `everyColdLaunchWhileInactive`, `disabled`; active всегда пропускает subscription paywall |
| 5 | `AppFlowSceneViewModel` + `ResolveSpecialOfferUseCase` | Close обычного paywall ведёт в optional offer либо прямо в main |
| 6 | `BroadTokenPaywallViewModel/View` + `TokenPurchaseManager` | `.tokens`, безопасный consumable fallback, backend fulfillment, pending/retry/recovery |
| 7 | `ExampleRecordingMonetizationAnalytics` + экран `Аналитика` | Live stream, count, update time, refresh/clear feedback и safe-paywall entry |
| 8 | `ExampleLaunchScenarios` | In-app действия отделены от cold-launch аргументов; у аргумента есть Copy, смысл, ожидание и путь Xcode |
| 9 | `BroadSupportEmailComposer` + `ExampleContactUsView` | Системный composer; Simulator fallback, Copy/Close и отдельный empty-address alert |
| 10 | `AgentPreflight.md` + `#agent-preflight` | Kaiten/Figma: MCP → Chrome → export → `BLOCKED`, затем ровно пять строк статуса |
| 11 | `#agent-build-prompt` | До UI обязательны screen map, backend matrix и monetization decision |
| 12 | `app-delivery-iterations-*.svg` + оба варианта README | Функциональная итерация отделена от screenshot-to-source и self-review |
| 13 | Якоря `#agent-preflight`, `#agent-build-prompt`, `#agent-app-check` | Три прямые ссылки сразу в Variant A; ручной путь повторяет шесть стадий |
| 14 | Корневой и example README + парные light/dark SVG | Быстрый выбор пути, карта всех flow, актуальные ссылки и объяснения |
| 15 | `BroadLogEvent` + `OSLogBroadLogger` + `Logging.md` | Закрытые enum/Bool/count; raw IDs и legacy metadata не попадают в Console |
| 16 | `Scripts/agent_gate.sh` + эта ручная матрица | Отдельные technical, functional, visual и instruction проверки без реальных платежей |

## Обязательные сценарии

| Сценарий | Действие | UI | Диагностика | Сохраняется | Нельзя |
|---|---|---|---|---|---|
| Первый запуск | Удалить app и запустить обычную scheme | Launch → onboarding → subscription paywall; verified active либо разрешённое закрытие ведёт в main, но premium открывает только active | `[FLOW] launch → onboarding → initial-paywall` | Onboarding checkpoint и выбранная paywall policy | Открывать premium до свежего entitlement |
| Повторный запуск | Полностью закрыть и снова открыть app | Onboarding не повторяется; paywall зависит от выбранной policy | `[FLOW] launch → main/initial-paywall` показывает фактический route | Checkpoint того же fixture namespace | Смешивать прогресс разных fixture |
| Premium active | Запустить active entitlement fixture | Main без subscription paywall | `[FLOW] launch → main`; premium подтверждается отдельным entitlement state | Только fixture checkpoint | Показывать subscription paywall |
| Premium inactive | Запустить inactive entitlement fixture | Subscription paywall по выбранной policy | `[FLOW] launch → initial-paywall` | Paywall checkpoint по policy | Выдавать premium |
| Premium unresolved | Запустить unresolved fixture | Обычный main доступен; premium-контент закрыт и есть безопасный retry | `[FLOW] launch → main`; `unknown` не логируется как `inactive` | Не записывать inactive/success | Превращать timeout/offline в inactive или premium |
| Paywall один раз | Выбрать `onceAfterOnboarding`, закрыть paywall и перезапустить | В текущей установке initial paywall больше не показывается | Сначала `[FLOW] initial-paywall → main`, после restart — `[FLOW] launch → main` | Initial paywall resolved checkpoint | Сбрасывать Keychain или payment pending |
| Paywall каждый cold launch | Выбрать `everyColdLaunchWhileInactive`, закрыть и перезапустить | Paywall вернётся на новом process launch, пока inactive | Сначала `[FLOW] initial-paywall → main`, после restart — `[FLOW] launch → initial-paywall` | Onboarding checkpoint; dismiss не становится permanent skip | Повторно показывать paywall в том же session |
| Paywall вручную | Открыть из main/Settings | Paywall открывается независимо от initial policy | Analytics UI и `[ANALYTICS] ... count=N`; отдельный flow-marker не создаётся | Initial checkpoint не меняется | Смешивать manual и initial presentation |
| Paywall закрыт, special offer отсутствует/выключен | Закрыть initial paywall | Main без ошибки | `[FLOW] initial-paywall → main` | Paywall progress по policy | Считать отсутствие config ошибкой |
| Paywall закрыт, special offer разрешён | В AppFlow или карточке Special Offer закрыть сначала обычный subscription paywall в enabled fixture | Resolver-loader → Special offer → close/purchase → main; общий экран аналитики видит события обоих paywall | `[FLOW] initial-paywall → special-offer`; один process recorder содержит обе презентации | Offer eligibility/cooldown только в своём store | Открывать offer напрямую из карточки, создавать отдельную невидимую аналитику, зацикливать offer или доверять feature gate из platform cache |
| Purchase/restore первого paywall | Завершить безопасный confirmed fixture первого subscription paywall | Entitlement refresh → main; Special Offer не открывается | `[FLOW] initial-paywall → main` после active | Подтверждённый entitlement, не offer state | Показывать downsell уже купившему пользователю |
| Subscription paywall | Открыть каталог подписок | 0/1/2/12/N продуктов в provider order | Typed analytics UI; Console получает только безопасный `[ANALYTICS] ... count=N` | Только safe presentation state | Фильтровать/сортировать SKU или открывать premium до refresh |
| Token paywall | Нажать на token balance или карточку fixture | Отдельные consumable-пакеты; новый баланс только после backend confirmation | Token-аналитика показывает outcomes; `[TOKENS] tokens.balance.confirmed` появляется только после backend snapshot | Pending evidence и backend balance того же account | Использовать subscription checkout, выдавать premium или начислять дважды |
| Token fallback на main | Запустить `-app-flow-main-only -token-paywall-main-fallback`, открыть token paywall | Остаётся consumable token UI; Accessibility value показывает requested `.tokens`, resolved `.main` | Token-аналитика показывает успешную загрузку; subscription completion отсутствует | Только safe presentation state | Принимать fallback, если в `main` есть subscription/unknown product |
| Analytics | Открыть/закрыть safe paywall и Special Offer flow, затем открыть аналитику; отдельно нажать refresh при пустом списке | Счётчик, общий live-список обеих презентаций, spinner, время update и явный результат «событий пока нет» | `[ANALYTICS] analytics.events.recorded count=N` | Один bounded in-memory recorder только до закрытия process | Показывать секреты/raw payload, терять события отдельного каталога или обещать persistence |
| Очистка Keychain | Debug → «Очистить Keychain» → подтвердить | Inline-результат с числом service; есть указание о перезапуске | UI — source of truth; отдельный OSLog с именами service намеренно не создаётся | Onboarding/paywall/cache/analytics/payment pending не меняются | Очищать чужие service, payment pending или попадать в Release |
| Сброс flow progress | Debug → «Сбросить onboarding/paywall» → подтвердить | Inline-результат и явное указание, что для нового flow нужен перезапуск | UI — source of truth; следующий cold launch доказывает новый route через `[FLOW]` | Keychain/cache/analytics/payment pending не меняются | Считать сброс entitlement или restore |
| Очистка кеша | Debug → «Очистить кеш контента» | Inline-результат с числом удалённых entries | `[CACHE] cache.operation.completed operation=remove` без физического cache key | Keychain/progress/analytics/payment pending не меняются | Удалять entitlement, token balance или pending operation |
| Очистка аналитики | Debug → «Очистить события» | Список сразу становится пустым; виден результат | `[ANALYTICS] analytics.events.recorded count=0` | Остальные stores не меняются | Очищать backend analytics или обещать восстановление |
| Contact Us, почта настроена | Открыть «Contact Us» | Composer с формой `SupportEmail.md` | Результат composer виден в UI; адрес, IDs и body в Console не пишутся | Ничего | Логировать адрес, IDs или support log |
| Contact Us, почта не настроена | Открыть «Contact Us» в Simulator | Alert «Почта не настроена», Copy email и Close | Alert — source of truth; OSLog намеренно не содержит support email | Ничего | Показывать пустой экран или зависать |
| Launch arguments | Debug → «Сценарии запуска» | In-app fixtures открываются тапом; cold-launch argument имеет Copy и путь в Xcode | После restart фактический route/state подтверждает профильный typed log или Accessibility value | Ничего | Обещать применить ProcessInfo argument без restart |
| Kaiten и дизайн доступны | Выполнить preflight-промпт | Отчёт показывает статусы входов, отдельно разрешение на безопасный каркас и на все обязательные функции | `[INPUT]` остаётся в видимом отчёте агента; runtime Console здесь не участвует | Ничего | Начинать Swift-код до `PLAN REVIEW REQUIRED` и проверки плана |
| Kaiten или дизайн недоступны | Выполнить preflight без MCP/browser/export | Отчёт `BLOCKED`, какого источника нет и у кого его запросить | `[BLOCKED]` остаётся в отчёте с ответственным, без секретов | Ничего | Придумывать «похожий» UI, endpoint или контент |
| Backend/SDK action | Нажать «Проверить loader» | Spinner до первого `await`, double tap закрыт, результат рядом с кнопкой | Inline-result доказывает completion; произвольный backend text в OSLog не отправляется | Ничего | Визуально «зависать» или показывать result у соседней кнопки |

## Отдельная проверка замечаний внутреннего ревью

Ниже каждое замечание первого разработчика вынесено в собственный сценарий.
Строка считается закрытой только после проверки фактического поведения, а не
по наличию похожего текста или кнопки.

| Замечание | Что проверить | Ожидаемый результат | Где закрывается в плане |
|---|---|---|---|
| Результат очистки кеша выглядел как сообщение от верхней кнопки | Последовательно нажать backend-fixture и очистку кеша | У каждого действия свой spinner и свой inline-результат внутри его секции | Шаг 3 |
| После нажатия backend-кнопки интерфейс выглядел зависшим до следующего экрана | Нажать действие дважды подряд | Spinner появляется синхронно, повторный тап заблокирован | Шаги 2–3, 15 |
| Нельзя было проверить paywall при каждом запуске | Выбрать каждую initial-paywall policy и сделать cold launch | `once`, `everyColdLaunchWhileInactive` и `disabled` дают разные предсказуемые маршруты | Шаг 4 |
| После закрытия paywall не появился special offer | Закрыть обычный paywall без покупки при включённом offer | Разрешённый offer открывается один раз; выключенный или отсутствующий ведёт на main | Шаг 5 |
| Очистка Keychain не вернула onboarding/paywall | Очистить Keychain, затем отдельно сбросить flow progress | Keychain не меняет flow; paywall возвращает только отдельный reset progress | Шаг 3 |
| «Очистить события» визуально ничего не делала | Создать события, очистить и посмотреть результат | Видно число удалённых записей; список пуст; кнопка disabled | Шаг 7 |
| «Обновить события» визуально ничего не делала | Нажать refresh при пустом и заполненном списке | Видны spinner, время обновления и актуальное число событий | Шаг 7 |
| Непонятно, откуда берутся события без покупки | Открыть, выбрать продукт и закрыть fixture-paywall | Видны load started/succeeded, show, select и close без настоящей оплаты | Шаг 7 |
| Список launch arguments ничего не объяснял и не нажимался | Открыть каждый элемент списка | In-app сценарии открываются; cold-launch аргументы копируются и объясняют restart | Шаг 8 |
| На main не было работающих кнопок | Нажать каждую карточку каталога и вернуться | Каждая карточка открывает безопасный экран; мёртвых действий нет | Шаг 2 |
| В Variant A было непонятно, где взять prompts | Нажать ссылку в шаге 4 Variant A | Открывается `AgentPromptPack.md`; каждый этап находится отдельным copy-paste блоком | Шаг 13 |
| Было непонятно, когда запускать проверку | Пройти review-точки из Prompt Pack | Functional, visual и final acceptance запускаются только после предыдущего checkpoint | Шаг 13 |
| README ссылался на «шаг 4» и «шаг 6» без перехода | Проверить все упоминания шагов и промптов | Каждое упоминание имеет понятный заголовок или кликабельный якорь | Шаг 13 |
| Kaiten MCP не подключился | Выполнить preflight без Kaiten MCP | Агент пробует авторизованный Chrome, затем экспорт; иначе возвращает BLOCKED | Шаг 10 |
| Агент нарисовал лишь похожий интерфейс | Сравнить каждый экран с его Figma/no-code источником | После функциональной сборки выполнена отдельная визуальная итерация screenshot-to-source | Шаги 10–12 |
| Premium-toggle не пропустил subscription paywall | Включить active premium fixture и повторить flow | Active entitlement всегда ведёт на main без subscription paywall | Шаг 4 |
| Contact Us без почты не показал понятный результат | Открыть Contact Us в Simulator без аккаунта Mail | Alert предлагает Copy email и Close; пустого экрана нет | Шаг 9 |
| Onboarding, subscription paywall и token paywall не совпали с исходниками | Сверить карту экранов и screenshots до передачи QA | Все обязательные экраны существуют и прошли отдельную визуальную итерацию | Шаги 11–12, 16 |
| Вместо token paywall открылся subscription paywall | Нажать token balance и открыть `.tokens` | Открывается отдельный consumable UI и отдельный ViewModel | Шаг 6 |
| Backend-hook зачисления токенов пришлось добавлять вручную | Выполнить fixture-покупку токенов | Баланс меняется только после `TokenFulfillmentRepository`; callback возвращает подтверждённый snapshot | Шаг 6 |
| API-логику пришлось дописывать после автоматической генерации | Сверить каждую функцию с `AppIntegrationPlan.md` | До Swift зафиксированы method/endpoint/request/response/auth/errors/retry; неизвестное остаётся `BLOCKED` | Шаг 11 |
| Разработчику неясно, когда приложение можно отдавать QA | Пройти функциональную и визуальную итерации | QA получает приложение только после обеих итераций и личной проверки разработчика | Шаги 12, 16 |

## Порядок приёмки

1. Сначала выполните `bash Scripts/agent_gate.sh`.
2. Затем пройдите сценарии на маленьком и большом iPhone Simulator.
3. Открывайте настоящий Adapty только для load/show; не запускайте
   purchase, restore или RU checkout.
4. После перезапуска проверьте, что сохранилось только указанное в
   колонке «Сохраняется».
5. При любом расхождении зафиксируйте сценарий, фактический UI и безопасную
   диагностику; не маскируйте ошибку кнопкой `PASS`.
