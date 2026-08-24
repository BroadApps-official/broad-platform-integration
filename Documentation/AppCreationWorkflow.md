# Поэтапное создание приложения с агентом

Этот процесс используется для любого host app на BroadApps iOS Platform. Он не
привязан к номеру проекта и не обещает, что один prompt автоматически перенесёт
всю логику reference-приложения.

> [!IMPORTANT]
> Если приложение уже работает на старом BroadApps monolith/local sources,
> используйте не этот общий creation workflow, а
> [staged-инструкцию для ИИ](LegacyAppMigrationAgent.md) или
> [ручную migration-инструкцию](MigrationGuide.md).

Главное правило: **агент не является источником продуктовых требований**. Он
может собрать platform-based каркас, реализовать подтверждённый контракт и
проверить результат. Отсутствующий экран, endpoint, backend hook или правило
исходника получает `BLOCKED`, а не правдоподобную догадку.

## Кто за что отвечает

| Область | Платформа | Агент | Разработчик приложения |
|---|---|---|---|
| AppFlow, entitlement, paywall mechanics, Special Offer, pending, cache/retry | Даёт готовые контракты и компоненты | Подключает без копирования внутренней логики | Выбирает app-owned policy и подтверждает поведение |
| Backend и бизнес-правила исходника | Даёт границы repository/use case | Переносит только доказанный contract | Подтверждает mapping, auth, hook и расхождения |
| Экран конкретного бренда | Даёт общие UI-состояния | Реализует по точному source frame | Подтверждает functional flow и принимает visual |
| Внешние конфигурации | Даёт typed-модели и fail-closed правила | Подключает доступные public client values | Получает app-owned данные у владельцев |
| QA readiness | Даёт checklist и platform gate | Собирает evidence | Лично проходит checkpoint и принимает передачу |

Платформа не хранит статусы и материалы конкретного приложения. Заполняемые
артефакты копируются в repository host app.

## Обязательный рабочий артефакт

До Swift-правок скопируйте
[`Templates/AppIntegrationPlan.md`](Templates/AppIntegrationPlan.md) в
`Documentation/AppIntegrationPlan.md` host app и заполните его фактическими
ссылками и статусами.

Это не второй паспорт проекта: Kaiten остаётся источником исходных данных.
Integration Plan хранит только доказанное техническое сопоставление:

```text
требование → источник → экран → backend → platform component → app-owned код
```

Credentials, bearer tokens, private keys, receipt/JWS и полный payload в этот
файл не записываются.

## Семь этапов вместо одного большого prompt

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="Assets/README/app-delivery-iterations-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="Assets/README/app-delivery-iterations-light.svg">
  <img alt="Семь этапов создания приложения, developer checkpoints и безопасное возобновление после BLOCKED" src="Assets/README/app-delivery-iterations-light.svg" width="100%">
</picture>

Схема читается слева направо. Нижняя ветка не является обходным путём: она
останавливает только зависимую функцию, ждёт evidence, обновляет Plan и
возвращает работу к тому же stage.

### Этап 0. Preflight без записи файлов

Агент проверяет Kaiten, design source, reference, backend и продуктовые решения.
Он отдельно отвечает:

```text
Можно создать безопасный каркас: ДА / НЕТ
Можно реализовать все обязательные функции: ДА / НЕТ
```

Каркас разрешён только когда известны identity проекта, platform source и
базовая карта модулей. Отдельный `BLOCKED` не запрещает независимый каркас или
другой `READY`-срез, но заблокированная функция не получает production UI,
выдуманный endpoint или скрытую заглушку.

### Этап 1. Integration Plan, всё ещё без Swift

Агент создаёт только `Documentation/AppIntegrationPlan.md`, заполняет screen
map, backend matrix, monetization decisions и порядок вертикальных срезов.

Конечный статус:

```text
PLAN REVIEW REQUIRED
```

Разработчик подтверждает границы и порядок. До подтверждения создание проекта и
массовая генерация Swift запрещены.

### Этап 2. Platform-based каркас

Агент создаёт iPhone target с `Team = None`, подключает package products,
composition root, AppConfiguration, безопасный bootstrap, Debug Status и пустые
route entry points только для `READY`-областей.

Каркас обязан собираться, но **не считается подключённым backend или готовым
приложением**. Fixture разрешён только как явно подписанный fixture.

Конечный статус:

```text
SKELETON REVIEW REQUIRED
```

### Этап 3. Один вертикальный срез за раз

Один срез — один пользовательский путь целиком:

```text
View → ViewModel → use case → repository → SDK/backend → typed result → UI
```

Каждый prompt называет ровно одну функцию из Integration Plan. Агент не меняет
соседние `BLOCKED`-области и не начинает следующий срез автоматически.

Готовый срез должен иметь loading/content/empty/error/offline, защиту double
tap, безопасные логи и воспроизводимый результат. Конечный статус:

```text
SLICE REVIEW REQUIRED: <название функции>
```

### Этап 4. Функциональный аудит

После всех доступных срезов агент проверяет маршруты, API mapping, монетизацию,
recovery, pending, analytics, Debug/Release и Simulator fixtures. Он не начинает
визуальную полировку и возвращает:

```text
FUNCTIONAL REVIEW REQUIRED
```

Разработчик лично проверяет бизнес-поведение и подтверждает продолжение.

### Этап 5. Визуальная итерация

Каждый экран сравнивается со своим source frame на маленьком и большом iPhone
Simulator. Агент исправляет один экран или связанную группу состояний за раз.
Общий фон, похожая композиция или UI reference не заменяют Figma/no-code source.

Конечный статус:

```text
VISUAL REVIEW REQUIRED
```

### Этап 6. Финальная acceptance и handoff

После developer review агент проходит
[`ProjectDelivery.md`](ProjectDelivery.md), проверяет app-owned configuration,
безопасные runtime logs, Debug/Release и готовит QA steps. Настоящие purchase,
restore и RU checkout не выполняются.

Только на этом этапе допустим итог `READY FOR QA`. Platform `PASS` не заменяет
этот app-level вердикт.

## Стоп-правила

Агент обязан остановить конкретную область, если:

- источник экрана не открыт или противоречит другому источнику;
- обязательной backend-ручки, поля, auth или правила retry нет;
- неизвестно, какой hook исходника меняет server-owned состояние;
- subscription, tokens, RU Billing или Special Offer не имеют подтверждённого
  продуктового решения;
- fixture пытаются выдать за production backend или live Dashboard;
- предыдущий developer checkpoint не подтверждён.

Формат блокера:

```text
[BLOCKED] <функция>
Нет: <конкретный источник или решение>.
Доказательство: <где искали>.
Владелец: <PM / designer / backend owner / tech lead>.
Независимая работа, которую можно продолжить: <список или «нет»>.
```

## Как действовать в типовых ситуациях

| Ситуация | Что можно делать | Что нельзя делать | Следующая точка |
|---|---|---|---|
| Все обязательные входы `READY` | Идти по этапам 0–6 | Перепрыгивать developer checkpoint | Следующий checkpoint |
| Backend `PARTIAL` | План, каркас и независимые `READY`-срезы | Придумывать endpoint/schema/hook заблокированной функции | Ответ backend owner → обновить Plan → продолжить этот срез |
| Нет source frame одного экрана | Функционально проверить независимые области | Рисовать похожий production UI для этого экрана | Source от designer/PM → visual stage этого экрана |
| Монетизация или другая feature не входит в scope | Зафиксировать доказанный `N/A` | Оставлять пустую строку или подключать feature «на всякий случай» | Продолжить независимый scope |
| Каркас разрешён, но не все функции | Создать только границы `READY`-областей | Выдавать skeleton/fixture за готовый backend | `SKELETON REVIEW REQUIRED` |
| Blocker снят | Добавить новое evidence и изменить только связанные строки Plan | Перестраивать подтверждённые соседние срезы без причины | Вернуться к остановленному этапу |
| Работа продолжается в новом чате/другим агентом | Сначала перечитать Plan, последний checkpoint и diff | Начинать заново или предполагать, что checkpoint подтверждён | Тот же незавершённый этап |
| Уже существует app-код | Сначала описать текущее и целевое состояние в Plan; этап 2 становится аудитом composition root/границ | Переписывать всё приложение до gap analysis | Один подтверждённый исправляющий срез |
| Разработка без агента | Использовать тот же Plan, порядок и evidence вручную | Пропускать checkpoints из-за отсутствия prompts | Тот же stage status |
| Изменён только host app | Собрать и принять target приложения | Выдавать platform gate за app acceptance | `READY FOR QA` или app-level `BLOCKED` |
| Изменена платформа | Дополнительно запустить `bash Scripts/agent_gate.sh` | Требовать Signing Team или настоящий платёж | Platform PASS + отдельная app acceptance |

`N/A` допустим только при доказанном решении, что функция не входит в scope.
Отсутствующий источник — это `BLOCKED`, а не `N/A`.

## Как безопасно продолжить после паузы

1. Открыть `Documentation/AppIntegrationPlan.md` host app.
2. Найти последний подтверждённый checkpoint и незавершённый срез.
3. Проверить, появилось ли новое evidence по blocker-у.
4. Обновить только связанные строки Plan.
5. Повторить остановленный stage; уже принятые этапы не генерировать заново.

Если текущий код расходится с Plan, сначала вернуть `PLAN REVIEW REQUIRED` с
описанием diff. Молчаливое изменение scope запрещено.

## Что считается хорошей автоматизацией

- агент пишет меньше кода до появления доказанных контрактов;
- developer checkpoint проверяет решения, а не каждую строку;
- один дефект не размазывается по всему приложению;
- platform logic не копируется в host app;
- app-owned logic не объявляется частью платформы;
- итоговый отчёт показывает `READY`, `BLOCKED` и `N/A` по функциям, а не один
  безусловный `PASS`.

Готовые тексты для всех этапов находятся в
[`AgentPromptPack.md`](AgentPromptPack.md). Обезличенный пример заполнения — в
[`Examples/NeutralAppIntegrationPlan.md`](Examples/NeutralAppIntegrationPlan.md).
