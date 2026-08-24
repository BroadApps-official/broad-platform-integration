# Набор поэтапных промптов для создания приложения

Эти промпты отправляются **по одному** в одном чате. Не объединяйте их в один
запрос. Перед следующим этапом прочитайте отчёт агента и подтвердите указанный
checkpoint.

Полный порядок и границы ответственности:
[`AppCreationWorkflow.md`](AppCreationWorkflow.md). Заполняемый документ:
[`Templates/AppIntegrationPlan.md`](Templates/AppIntegrationPlan.md).

## 0. Preflight: только чтение

Замените значения в угловых скобках:

```text
Проведи preflight нового iPhone-приложения на BroadApps iOS Platform.

Проект: <НАЗВАНИЕ ТЕКУЩЕГО ПРИЛОЖЕНИЯ>.
Kaiten: <ССЫЛКА / НАЗВАНИЕ / ЭКСПОРТ>.
Reference: <ССЫЛКА / ПУТЬ / НАЙДИ>.

Пока не создавай и не изменяй файлы приложения.

1. Прочитай AGENTS.md, README.md, Documentation/AgentPreflight.md и
   Documentation/AppCreationWorkflow.md платформы.
2. Проверь фактический доступ к Kaiten, design source, read-only reference,
   backend contracts, monetization decisions и support/legal.
3. Не считай ссылку доказательством, пока её содержимое не прочитано.
4. Не придумывай экран, endpoint, поле, auth, backend hook или правило исходника.
5. Для каждого расхождения укажи функцию, доказательство и владельца решения.

Верни только:

Kaiten: READY / BLOCKED
Design source: READY / BLOCKED
Reference: READY / BLOCKED / N/A
Backend: READY / PARTIAL / BLOCKED
Monetization: READY / BLOCKED / N/A
Можно создать безопасный каркас: ДА / НЕТ
Можно реализовать все обязательные функции: ДА / НЕТ

Затем перечисли [BLOCKED] в формате из AppCreationWorkflow.md и независимые
области, которые можно продолжить. Не пиши Swift и не создавай проект.
```

## 1. Integration Plan: без Swift

Отправляйте после preflight. Этот этап не разрешает создавать Xcode project.

```text
Создай только план интеграции текущего приложения.

1. Прочитай результат preflight и
   Documentation/Templates/AppIntegrationPlan.md платформы.
2. В repository приложения создай Documentation/AppIntegrationPlan.md по
   шаблону. Не создавай и не изменяй Swift, Xcode project или конфигурации.
3. Заполни фактическими доказательствами:
   - входы и владельцев blockers;
   - ownership platform / agent / app developer;
   - карту всех экранов и состояний;
   - backend method/request/response/auth/errors/retry и server-owned hooks;
   - monetization decisions;
   - независимые вертикальные срезы и порядок реализации.
4. Для неизвестного поставь BLOCKED. Не создавай предполагаемый endpoint,
   локальную production-заглушку или похожий экран.
5. Не переноси внутреннюю логику платформы в host app.

В конце верни PLAN REVIEW REQUIRED, короткий список READY-срезов и каждый
BLOCKED с владельцем. Остановись и жди подтверждения разработчика.
```

## 2. Безопасный каркас

Отправляйте только после явного подтверждения `PLAN REVIEW REQUIRED`.

```text
Разработчик подтвердил Integration Plan. Создай только platform-based каркас.

1. Работай строго по Documentation/AppIntegrationPlan.md текущего приложения.
2. Создай iPhone target с Team = None и без test targets.
3. Подключи BroadCore, BroadMonetization, BroadUIFlows и при необходимости
   BroadExtensions. Собери один composition root и AppConfiguration.
4. Подключи безопасный bootstrap, AppFlow entry points, Debug Status и typed
   logging. Используй fixture только с явной маркировкой fixture.
5. Не реализуй backend feature, app-specific hook или точный UI экрана на этом
   этапе. Не трогай BLOCKED-области.
6. Собери Debug и Release для iPhone Simulator. Не выполняй purchase, restore
   или RU checkout.
7. Обнови в Integration Plan только фактический статус каркаса.

В конце верни SKELETON REVIEW REQUIRED, список созданных границ, команды сборки
и то, что намеренно ещё не реализовано. Остановись.
```

## 3. Один вертикальный срез

Отправляйте отдельно для каждой `READY`-строки Integration Plan.

```text
Реализуй только вертикальный срез: <ТОЧНОЕ НАЗВАНИЕ ИЗ INTEGRATION PLAN>.

1. Не расширяй scope и не начинай следующий срез.
2. Повтори доказанный путь View → ViewModel → use case → repository → client.
3. Используй только method/schema/auth/hook, записанные в Integration Plan.
   Если они неполны или код расходится с источником — поставь BLOCKED и
   останови этот срез; не угадывай.
4. Реализуй loading/content/empty/error/offline, immediate spinner и блокировку
   double tap. Не превращай timeout/pending в success.
5. Используй готовые platform contracts; не копируй их внутреннюю логику в app.
6. Проведи contract smoke по обезличенному production-shape fixture/schema и
   перечисли обязательные поля, которые дошли до UI.
7. Собери Debug/Release и пройди безопасный fixture flow.
8. Обнови только строки этого среза в Integration Plan.

В конце верни SLICE REVIEW REQUIRED: <НАЗВАНИЕ>, фактический результат,
изменённые файлы, команды и оставшиеся BLOCKED. Остановись.
```

## 4. Функциональный аудит

Отправляйте после developer review всех доступных срезов.

```text
Проведи функциональный аудит текущего приложения без визуальной полировки.

1. Сверь код с Documentation/AppIntegrationPlan.md и ProjectDelivery.md.
2. Проверь AppFlow, backend mapping, обязательные поля, loading/error/offline,
   recovery, pending, analytics и Debug Status.
3. Для monetization отдельно проверь active/inactive/unresolved, initial
   paywall policy, subscription/token separation, backend token fulfillment,
   Special Offer только после close первого paywall и purchase/restore bypass.
4. Проверь Contact Us fallback и независимые Debug storage actions.
5. Собери Debug/Release и пройди безопасные fixtures на iPhone Simulator.
6. Не выполняй настоящие purchase, restore или RU checkout.
7. Не исправляй визуальные расхождения, если они не ломают функциональность.
8. Найденные functional defects исправь, повтори аудит и обнови Integration Plan.

В конце верни FUNCTIONAL REVIEW REQUIRED. Отдельно перечисли READY, BLOCKED,
N/A и точные шаги, которые разработчик должен лично пройти. Остановись до его
подтверждения.
```

## 5. Визуальная итерация

Отправляйте только после подтверждения `FUNCTIONAL REVIEW REQUIRED`.

```text
Разработчик подтвердил функциональный flow. Выполни визуальную итерацию.

1. Возьми screen map и точные source frames из Integration Plan.
2. Сравнивай один экран и все его states за раз на маленьком и большом iPhone
   Simulator; при model-specific source используй также его размер.
3. Исправь composition, typography, color, spacing, assets, safe area, длинные
   тексты, loading/empty/error и keyboard states.
4. Не меняй подтверждённые backend, AppFlow и monetization contracts ради
   визуального сходства.
5. Экран без source оставь BLOCKED; не делай похожий дизайн от себя.
6. После каждого исправления повтори screenshot comparison.

В конце верни VISUAL REVIEW REQUIRED с таблицей экран → source → размеры →
результат и попроси разработчика лично посмотреть сборку. Остановись.
```

## 6. Финальная acceptance

```text
Разработчик подтвердил visual review. Подготовь app-level acceptance и handoff.

1. Пройди Documentation/ProjectDelivery.md и Integration Plan.
2. Повтори Debug/Release Simulator, safe fixtures, offline/retry/pending,
   analytics, Contact Us, persistence и runtime logging.
3. Проверь app-owned bundle/config/products/placements/legal/support без
   публикации credentials. Fixture и compile-only live scheme не выдавай за
   доказательство production Dashboard/backend.
4. Если менялись исходники BroadApps iOS Platform, отдельно запусти её
   bash Scripts/agent_gate.sh; platform PASS не заменяет app acceptance.
5. Не запускай настоящие purchase, restore или RU checkout и не требуй Signing
   Team.

Верни итог READY FOR QA только если все обязательные строки READY, а явно
исключённые из scope по решению владельца переведены в N/A с доказательством.
Пока хотя бы одна обязательная строка остаётся BLOCKED, верни APP CHECK ·
BLOCKED с одним конкретным следующим действием.
```

## Короткие точечные промпты после handoff

После создания приложения агенту можно давать узкие задачи: проверить один
endpoint, один screen state, token fulfillment, Special Offer, offline/pending
или конкретный visual diff. Любой такой prompt должен ссылаться на строку
Integration Plan и не разрешать менять соседние функции.
