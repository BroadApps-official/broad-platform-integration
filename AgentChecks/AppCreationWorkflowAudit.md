# Аудит универсального workflow создания приложений

Дата: 2026-08-24. Scope — только BroadApps iOS Platform, её документация и
автоматические contract checks. Код и execution status конкретных host apps в
этот аудит не входят.

## Итог

`PASS` — платформа больше не предлагает агенту создать всё приложение одним
prompt. Работа разделена на preflight, Integration Plan, безопасный каркас,
один вертикальный срез, functional review, visual review и acceptance. Каждый
переход имеет developer checkpoint.

## Аудит первой половины

После добавления workflow, шаблона и Prompt Pack выполнена отдельная сверка
README, developer/manual маршрутов и acceptance checklist.

Найдено и исправлено:

- старый монолитный build prompt оставался в закрытом архиве README и мог быть
  случайно скопирован — блок удалён полностью;
- preflight и acceptance продолжали использовать старый ответ
  `Можно начинать: ДА` — разрешение разделено на безопасный каркас и все
  обязательные функции;
- ручной путь не требовал Integration Plan — теперь он использует тот же
  screen/backend/ownership map и тот же порядок vertical slices;
- app integration contract не содержал plan/skeleton checkpoints — этапы и
  ссылки добавлены.
- прежний финальный prompt объединял visual review и acceptance — README теперь
  отправляет этапы 5 и 6 отдельно и требует подтверждения между ними.

После исправлений `bash Scripts/check_documentation.sh` и `git diff --check`
прошли без ошибок.

## Финальный аудит

| Риск | Защита платформы | Результат |
|---|---|---|
| Агент выдумывает отсутствующую логику исходника | Feature-level `BLOCKED` с evidence и owner | PASS |
| Ошибка одного предположения распространяется на весь app | Один vertical slice за prompt и developer review | PASS |
| Каркас выдают за рабочий backend | Отдельный `SKELETON REVIEW REQUIRED`; fixture не доказывает production | PASS |
| Похожий UI выдают за точный дизайн | Visual stage начинается после functional review и требует source frames | PASS |
| Platform PASS выдают за готовность host app | Отдельный `ProjectDelivery.md` и `READY FOR QA` | PASS |
| Workflow привязывается к одному номеру проекта | Все platform-owned тексты и отчёты обезличены | PASS |
| Требуется платный Apple Developer account | `Team = None`, iPhone Simulator и unsigned generic compile | PASS |
| Старый большой prompt возвращается в README | `check_documentation.sh` содержит forbidden-pattern check | PASS |

Нейтральный пример отдельно доказывает правильное частичное продолжение: экран
History остаётся `BLOCKED` без backend contract, а независимые каркас,
upload/result и subscription slices могут идти дальше после checkpoints. В
примере нет production-заглушки для отсутствующего endpoint.

## Проверки

```text
bash Scripts/check_documentation.sh
Documentation links and README assets are valid.

git diff --check
PASS

bash Scripts/agent_gate.sh
BroadApps iOS Platform agent gate passed.
```

Полный gate подтвердил rules/architecture/privacy/docs, SwiftFormat, SwiftLint,
package builds, iPhone Simulator, generic unsigned iOS compile и две compile-only
Adapty configurations. Настоящие purchase, restore и RU-платежи не запускались.

## Граница ответственности

Платформа даёт process, контракты, шаблон, prompts и проверки. Агент подключает
доказанные контракты по одному срезу. Разработчик конкретного app подтверждает
app-owned бизнес-правила, backend hooks и checkpoints. Платформа не хранит
номер, дизайн, execution status или готовность отдельного приложения.
