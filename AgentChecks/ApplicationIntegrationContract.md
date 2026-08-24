# Универсальный контракт интеграции приложения

Этот документ заменяет отчёты, привязанные к отдельному номеру приложения,
команде подписи или конкретному устройству. Он описывает одинаковую границу для
любого приложения, которое создаётся на BroadApps iOS Platform.

## Что подтверждает платформа

`bash Scripts/agent_gate.sh` проверяет сам package и `BroadAppTemplate`:

- архитектурные и продуктовые контракты;
- Debug/Release на маленьком и большом iPhone Simulator;
- generic iOS device compile без подписи;
- fixture-сценарии onboarding, paywall, tokens, special offer, RU Billing,
  Contact Us, аналитики и ошибок;
- privacy, документацию, style и compile-only live Adapty configurations.

Platform `PASS` не доказывает готовность автоматически созданного host app.
Каждое приложение получает собственные источники, backend и конфигурацию.

## Preflight любого приложения

До любого app-кода агент заполняет универсальную матрицу, затем копирует
[`AppIntegrationPlan.md`](../Documentation/Templates/AppIntegrationPlan.md) в
repository создаваемого приложения. План хранится рядом с приложением, а не в
platform-owned `AgentChecks`.

| Вход | Что должно быть известно | Если данных нет |
|---|---|---|
| Kaiten/ТЗ | Функции, состояния, тексты и продуктовые решения | `BLOCKED`, владелец — PM/product |
| Дизайн | Figma либо согласованный no-code source для каждого экрана | `BLOCKED`, владелец — designer/PM |
| Reference | Однозначный read-only пример, если он нужен | `BLOCKED`, владелец — tech lead/PM |
| Backend | Method, endpoint, request/response, auth, errors и retry | `BLOCKED`, владелец — backend owner |
| Монетизация | Policy, placements, products, access level и optional flow | `BLOCKED`, владелец — product/tech lead |
| RU Billing | `ru_pay` в Adapty, backend kill switch, catalog/auth/legal и optional Dashboard fallback | `BLOCKED`, если заменено Swift-default/fixture |
| Support/legal | Email, legal URL и обязательные тексты | `BLOCKED`, владелец — PM/legal |

Номер проекта и имя приложения записываются только в repository самого host
app. Platform-owned AgentChecks не создают отдельный отчёт под конкретный номер.

## Статус реализации host app

Для каждого приложения используется один и тот же порядок:

| Этап | Доказательство | Допустимый статус |
|---|---|---|
| Preflight | Все обязательные входы найдены или имеют владельца blocker-а | `READY/BLOCKED/N/A` |
| Integration Plan | Screen map, backend contracts, ownership и vertical slices записаны без Swift-кода | `PLAN REVIEW REQUIRED/BLOCKED` |
| Skeleton | Навигация, DI, состояния и безопасные заглушки собираются без выдуманной логики | `SKELETON REVIEW REQUIRED/BLOCKED` |
| Functional iteration | Routes, API, state machine, offline/retry и monetization fixtures | `READY/BLOCKED/N/A` |
| Functional review | Разработчик лично подтвердил поведение до визуальной полировки | `READY/BLOCKED` |
| Visual iteration | Каждый source frame сверен на двух размерах Simulator | `READY/BLOCKED/N/A` |
| Security/configuration | App-owned значения, logs, privacy и Release | `READY/BLOCKED/N/A` |
| QA handoff | Заполнен `Documentation/ProjectDelivery.md` | `READY/BLOCKED` |

Для existing app Integration Plan сначала фиксирует current behavior и gaps, а
Skeleton проверяет существующие target/DI/routes. После `BLOCKED`, паузы или
смены агента работа продолжается с последнего подтверждённого checkpoint;
принятые slices не генерируются повторно.

Fixture разрешён для разработки состояния, но не может доказать наличие
production backend, точного дизайна или конфигурации текущего приложения.

## Simulator-first политика

Базовый процесс команды не требует платного Apple Developer аккаунта,
provisioning или выбора Signing Team:

- в Xcode используется `Team = None`;
- разработка и обязательная визуальная/функциональная проверка выполняются на
  iPhone Simulator;
- platform gate дополнительно компилирует generic `iphoneos` target без подписи;
- агент не создаёт archive или подписанный `.ipa` и не помечает отсутствие
  signing как blocker.

Если компания даёт отдельный способ запустить сборку на iPhone, команда может
добавить результат в handoff самого приложения. Эта ручная проверка выполняется
вне platform gate, не требует от агента менять signing и не влияет на platform
`PASS`.

## Один актуальный checklist

Заполняемый документ для конкретного приложения —
[`Documentation/ProjectDelivery.md`](../Documentation/ProjectDelivery.md).
Именно в repository приложения разработчик хранит screen map, backend matrix,
статусы функций и QA evidence. Этот platform contract остаётся универсальным и
не копируется под каждый номер проекта.

Полный порядок остановок и review-точек описан в
[`AppCreationWorkflow.md`](../Documentation/AppCreationWorkflow.md), а готовые
поэтапные запросы — в
[`AgentPromptPack.md`](../Documentation/AgentPromptPack.md).
