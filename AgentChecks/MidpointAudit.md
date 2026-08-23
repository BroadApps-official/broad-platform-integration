# Аудит этапов 1–5

Дата: 2026-08-23. Аудит выполнен после preflight первого реального приложения
и до перехода к этапам 6–11.

## Итог

Платформенная часть этапов 1–5 подтверждена. Один documentation safety defect
исправлен. Внешние проверки не превращены в ложный `PASS`: независимый
README-тест человеком, device-only приёмка и входы проекта 5135 остаются
явными handoff/blocker-пунктами.

## Проверка по этапам

| Этап | Аудит | Результат |
|---|---|---|
| 1. Фиксация | Commit `686acd2`, полный gate, secret/artifact/reference scan | PASS |
| 2. README | Cold-read нашёл отсутствие единого критерия QA readiness; добавлен Project Delivery и прямой маршрут | PASS для документации; внешний human test ещё нужен |
| 3. Template | Отдельный фактический отчёт, два Simulator, AppFlow/special/token matrix | PASS |
| 4. Physical iPhone | Устройство найдено; signing team не задан, ручные Mail/ATT/VoiceOver проверки не выполнены | BLOCKED без ложного Simulator substitution |
| 5. 5135 preflight | Kaiten прочитан; Figma exact context, ТЗ, reference и backend contracts недостаточны | BLOCKED с владельцами пробелов |

## Что найдено и исправлено

### 1. Загрязнённый entitlement fixture-progress

Первый последовательный прогон использовал общий сохранённый onboarding
namespace и мог показать main для `inactive`. Этот результат отброшен.
BroadAppTemplate переустановлен только на тестовом Simulator, а entitlement
матрица повторена с `-app-flow-paywall-only`, который использует отдельный
entitlement namespace. В acceptance-report записан только повторный результат.

### 2. Слишком широкое разрешение на конфигурацию reference

README допускал временное копирование development-конфигурации похожего live
app и даже временного signing team/bundle. Такая формулировка могла привести к
копированию чужого provisioning/account state.

Исправлено в корневом README, Traceability и Usedesk:

- разрешены fixture либо явно согласованные публичные SDK/placement/product
  identifiers только для безопасного load/show;
- bundle нового приложения остаётся уникальным;
- без team используется Simulator/generic unsigned build;
- signing team, credentials, App Store keys/certificates, backend auth,
  api/user chat tokens и account/user data из reference запрещены.

### 3. Граница независимого README-теста

Cold-read и повторная проверка навигации выполнены, но тот же исполнитель не
может заменить нового человека. В QA handoff остаётся короткий внешний маршрут:
дать разработчику только корневой README и получить его замечания без подсказок.

## Повторные проверки после исправлений

- `git diff --check` — PASS;
- `bash Scripts/check_documentation.sh` — PASS;
- поиск private-key/Bearer/client-secret patterns — совпадений нет;
- поиск личных абсолютных путей и чувствительных значений Kaiten в
  `README.md`, `Documentation` и `AgentChecks` — совпадений нет;
- reference-проекты в commit этапа 1 не изменены.

## Решение о продолжении

Продолжать платформенные security, self-review и QA-handoff проверки можно.
Создавать production-функции и визуально объявлять 5135 готовым нельзя до
снятия blocker-ов из `Project5135Preflight.md`.
