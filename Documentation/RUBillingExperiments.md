# RU Billing A/B в платформе

BroadMonetization 1.4.1 добавляет opt-in отчёт RU Billing и явный selector
backend-продуктов. Adapty продолжает назначать вариант; существующая оплата,
RU-gate, авторизация и обычный paywall сохраняют свои границы.

Канонический API и кодовые примеры принадлежат модулю:
[RUBillingExperiments.md](https://github.com/BroadApps-official/broad-monetization-ios/blob/main/Documentation/RUBillingExperiments.md).
На сайте доступны [инструкция и интерактивная конфигурация](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/ru-billing-ab-platform),
а также [контракт backend](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/ru-billing-ab-tests-developer).

## Выбор способа подключения

| Путь | Что делает разработчик |
|---|---|
| Кодом, готовые services/UIFlows | Создаёт tracker через существующий RU composition и передаёт optional `ruBillingExperiments` в Adapty factory |
| Кодом, полностью свой lifecycle | Вызывает `trackShown` при появлении, закрывает presentation, сам исполняет только outcome `.useAdapty` |
| Через агента | Сначала аудит текущего AppIntegrationPlan и backend contract review, затем тот же API отдельным принятым slice |
| Существующий собственный A/B | Сохраняет его до явного cutover; одновременно два отправителя не включает |

Выбор backend-продуктов подключается отдельно только к host RU UI.
`RUExperimentCatalogSelector` возвращает совпадения ID, затем defaults, затем
полный раздел. Он сохраняет порядок/дубли и не меняет исходный каталог.
Special Offer всегда требует отмеченную backend-строку. Готовые Adapty
экраны продолжают использовать весь SDK product array и exact raw references.

## Граница совместимости

- Без optional tracker сетевых A/B-запросов нет, старые initializer действуют.
- Отсутствующий `isDefault` означает false; прежний каталог остаётся пригодным.
- `experiment_code` и `segment_code` принадлежат только текущему свежему payload,
  а не last-valid или persisted cache.
- RU Billing требует прежний проверенный `.verifiedFreshRemote` и RU-регион
  iPhone либо live Storefront. Стандартный provider-managed SDK callback не
  доказывает свежесть и не открывает RU Billing одним подключением tracker.
- Assign и shown используют ту же session-bound авторизацию, что checkout.
  Ошибка assign не создаёт shown с неподтверждённым кодом, UI не блокируется.
- Отчёт не открывает Premium, не запускает оплату, не повторяет её и не меняет
  entitlement/reconciliation. Ошибка RU-отчёта не уходит в Adapty.

## Проверка существующего приложения

Сначала соберите его с новой версией без tracker. Затем отдельным изменением
подключите его и проверьте реальные host-граничные условия: RU off/on,
доказательство свежести, корректные/отсутствующие коды, exact ID/defaults,
fallback placement, assign mismatch/failure, повторное открытие и logout.
Используйте fixture HTTP и compile-only SDK; не выдавайте это за проверку
конверсии реального backend. При миграции соблюдайте
[staged workflow](AppCreationWorkflow.md) и принятые checkpoints Integration Plan.
