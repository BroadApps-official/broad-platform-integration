# Аудит полного README перед федерацией repositories

## Source snapshot

Последняя полная версия общего README перед переходом на короткий federated
guide:

```text
commit: ff54c4d30c93deed039faced2537756f713f41e4
date:   2026-08-24 18:28:07 +03:00
title:  fix(monetization): restore provider special offer flow
size:   2 829 lines / 214 626 bytes / 58 referenced media files
```

Следующий README-changing commit `e023de6` опубликовал modular platform guide и
сократил документ до 550 строк. Поэтому `ff54c4d` является последним snapshot,
который соответствует показанным большим разделам, screenshots и GIF.

## Метод проверки

Каждый раздел snapshot сверялся не только с текущим текстом, но и с:

- `Package.swift` и dependency graph четырёх public modules;
- released public API/report и module README `1.0.0`;
- текущими platform contracts в `Documentation/`;
- `Compatibility/current.yml`;
- executable/static gates и текущим BroadAppTemplate;
- public repository ownership после ADR-0006.

Правило переноса: operational behavior сохраняется, если подтверждается текущим
code/docs/gate. Старое расположение файлов, umbrella installation и app-specific
design не превращаются в новый platform contract.

## Куда перенесены актуальные материалы

| Материал старого README | Современный owner | Публичная точка чтения |
|---|---|---|
| Bootstrap, critical/background steps, cache, retry/timeout | `broad-core-ios` | Core README + сайт `runtime-reliability` |
| Typed state, safe logs, async feedback, ATT adapter boundary | `broad-core-ios` | Core README + сайт `runtime-reliability`/`onboarding-att` |
| Adapty paywall/products, raw registry, placements, fallback | `broad-monetization-ios` | Monetization README + сайт `adapty-setup` |
| Entitlement, purchase/restore, pending, account recovery | `broad-monetization-ios` | Monetization README + сайт `runtime-reliability` |
| Remote Config, Special Offer и strict `ru_pay` provenance | `broad-monetization-ios` | Monetization README + сайт `special-offer`/`ru-billing` |
| Token fulfillment и balance recovery | `broad-monetization-ios` + backend host app | Monetization README + сайт `token-paywall` |
| AppFlow, onboarding, adaptive paywall, loader и payment sheets | `broad-ui-flows-ios` | UIFlows README + сайт `onboarding-att`/`paywall-ui` |
| Special Offer и RU UI sequence | `broad-ui-flows-ios` | UIFlows README + сайт `special-offer`/`ru-billing` |
| Hex/font/keyboard/swipe helpers | `broad-extensions-ios` | Extensions README/DocC |
| App creation, Kaiten/Figma/reference и Integration Plan | integration repository | Agent Preflight, Workflow и Prompt Pack |
| Usedesk GUI и account token sync | host app integration | `Documentation/Usedesk.md` + сайт `usedesk` |
| Cross-module compatibility и migration | integration repository | Compatibility catalog + migration guides + сайт |

## Что подтверждено без изменения смысла

### Adapty

- naming convention `nottrial` остаётся командным правилом, но runtime не
  определяет behavior по product name;
- базовые paywall names — `main`, optional `tokens` и `special_offer`;
- базовые placement IDs — `onboarding`, `pro_icon`, `settings`, `main`, `CTR`,
  `special_offer`; дополнительные mappings принадлежат app specification;
- products проходят `getPaywall → getPaywallProducts → 1:1 mapping → raw
  registry` без filter/sort/dedup;
- `special_offer` проверяется после полного parsing и может использовать
  current provider-managed payload;
- `ru_pay` остаётся fail-closed и требует `.verifiedFreshRemote`.

### UI

- onboarding length равна `pages.count`, три страницы — только fixture;
- ATT возможен только после видимого первого слайда;
- paywall показывает 0, 1 или N provider products;
- product tap не затемняет и не уменьшает карточку;
- loader сохраняет предыдущий контент и блокирует duplicate action;
- Special Offer является только вторым paywall;
- RU flow идёт от тарифа к method/consent/receipt/checkout/reconciliation.

### Financial reliability

- callback purchase/restore/RU return не выдаёт premium;
- доступ открывает только новая confirmed entitlement-проверка;
- pending не превращается в success/failure по timeout;
- token balance и RU purchases восстанавливаются backend текущего app account;
- transaction/checkout IDs нужны для exactly-once fulfillment, а не как вход
  обычного recovery.

## Что обновлено при переносе

| Старое представление | Актуальная формулировка |
|---|---|
| Один `BroadAppsIOSPlatform` Swift Package подключается к app | Host выбирает public products `BroadCore`, `BroadMonetization`, `BroadUIFlows`, `BroadExtensions` напрямую |
| Repository `BroadCore/vers_niiaz` является точкой установки | Канонический catalog/workflow — `broad-platform-integration`; module code — отдельные `broad-*-ios` repositories |
| Один root README владеет всеми API | Owner module README/DocC владеет API, сайт является главным cross-repository справочником |
| Один порядок migration «снизу вверх» | Агент выводит cutover topology и выбирает independent boundaries либо atomic cutover group |
| Provider cache одинаково ограничивает все flags | Special Offer и `ru_pay` имеют разные capability/provenance rules |

## Что намеренно не размножено

### Устаревшее

- инструкция добавить один старый umbrella package;
- branch `vers_niiaz` как источник новых versions;
- шаги, предполагающие отдельный root `.xcodeproj` монолита;
- старые prompts, которые не используют canonical platform source и
  Integration Plan checkpoints.

### App-owned или чувствительное

- внутренний screenshot сообщения сотрудника с именем/avatar: его проверенные
  Adapty-правила перенесены в публичную таблицу без персональных данных;
- реальные keys, account data, product/backend credentials и private URLs;
- тексты, цены, скидки, illustrations и число packages reference-приложения;
- trial toggle из loader GIF: GIF сохранён только как пример overlay behavior.

## Медиа

Сохранены и повторно опубликованы только материалы, которые объясняют текущий
contract:

- platform architecture/composition/startup/Remote Config diagrams;
- adaptive paywall и full-flow GIF;
- catalog/purchase loader GIF;
- fixture paywall states 0/1/2/N;
- Special Offer step 1/2;
- token paywall reference;
- RU tariff/method/consent/receipt/checkout/reference states;
- Usedesk Settings/chat/sanitized data map.

Каждый app screenshot/GIF помечен как `fixture` или `reference`: он показывает
поведение и последовательность, но не становится обязательным дизайном,
catalog или доказательством реальной финансовой операции.

## Результат

Большой README не восстановлен как новый монолит. Его актуальное знание
распределено по owner repositories, а сайт объединяет те же operational guides,
визуальные references и полный cross-repository keyword search.
