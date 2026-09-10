# Аудит содержания README

## Сверка README и сайта — 10 сентября 2026

Источник сверки: README integration commit
`200687f03d42dd97e143364e01bdcf033ec0f9d6` (650 строк), сайт из `broad-docs/content`
и совместимый набор 3.0.0. README сокращён до входной инструкции; исходные
инженерные документы и сценарии сохранены рядом с кодом.

| Тема прежнего README | Где читать на сайте | Результат сверки |
|---|---|---|
| Выбор модулей, зависимости, repositories | [Выбор модулей](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/module-selection), [архитектура](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/architecture) | Уже раскрыто; в README оставлены краткая таблица и корректная схема выбора |
| Установка, Swift 5 / SwiftPM 6, app-owned configuration | [Первое подключение](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/getting-started), [архитектура](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/architecture) | Уже есть; сохранены essentials для первого запуска |
| Ручная разработка, агент, plan/checkpoints и QA | [Создание приложения](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/app-creation) | Уже есть; ссылки на исчезнувшие разделы заменены действующими |
| Legacy migration | [Переход со старого BroadCore](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/legacy-app-migration) | Уже есть; ручной и AI workflows остаются в Documentation |
| Onboarding, ATT, paywall и Special Offer | [Стандарт приложения](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/app-standard) и связанные статьи | Уже есть; повторные правила удалены из README |
| Placement config, main fallback и token/tokens | [Adapty](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/adapty-setup) | Сайт соответствует 2.0.1+; не возвращаем старое правило только main |
| RU gates, outage fallback, account-policy confirmation | [RU Billing](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/ru-billing) | Сайт полнее прежнего README: учитывает 3.0.0 и необязательный payment-status endpoint |
| Account recovery, pending и Usedesk | [Надёжность](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/runtime-reliability), [токены](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/token-paywall), [Usedesk](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/usedesk) | Уже есть; account identity и ограничения не потеряны |
| Запуск BroadAppTemplate, module/integration gate и границы PASS | [Стандарт приложения](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/app-standard) | Добавлены команды запуска, выбор схемы и отличие от BroadStart и app QA |
| Release и compatibility | [Выпуск](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/release-process), [версии](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/compatibility) | Уже есть; схема выпуска уточнена: candidate до тега, exact acceptance после |
| Работа с сайтом, источники и локальная публикация | [Документация](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/documentation) | Команды уже есть; уточнены роли короткого README, сайта и versioned API, исправлен старый пример версий |
| Словарь | [Словарь](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/glossary) | Уже есть; убрана повторная таблица из README |

Баннер сообщает, что самая актуальная документация для применения платформы
находится на сайте. API конкретного выпуска по-прежнему принадлежит тегу модуля.
Проверка README теперь требует краткость, essentials, баннер и прямые ссылки
на статьи; продуктовые контракты продолжают проверяться в owner-документах.

Ниже — исторический аудит до разделения repositories. Версии и размеры в нём
описывают тот snapshot, а не текущую платформу.

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
