# Preflight исходных материалов для агента

Этот preflight выполняется до Integration Plan и любого app-кода. Его цель — доказать, что
агент действительно видит продуктовые требования, источник интерфейса,
reference и backend-контракт. Сообщения «примерно понятно» или «сделаю похожий
экран» не являются успешным результатом.

> [!IMPORTANT]
> Это canonical source правил и copy-paste prompt для Stage 0. Блок в
> [Agent Prompt Pack](AgentPromptPack.md#0-preflight-только-чтение) зеркалит
> prompt дословно для удобства; documentation gate отклоняет любое расхождение.

## Порядок доступа

### Источник платформы

Canonical workflow и compatibility читаются из public repository
[`BroadApps-official/broad-platform-integration`](https://github.com/BroadApps-official/broad-platform-integration).
Агент возвращает фактически прочитанный commit SHA и `platform_set` в
preflight report. На Stage 1 эти значения записываются в
`Documentation/AppIntegrationPlan.md`. Stage 0 не создаёт и не изменяет
файлы. Private `BroadApps-official/BroadCore` может быть только legacy
evidence существующего приложения; он не заменяет canonical platform source.

Если public repository, нужный документ или `Compatibility/current.yml`
недоступны, вернуть `Platform source: BLOCKED`. Нельзя выбирать package URL или
version по памяти, private mirror либо названию Swift product.

### Kaiten

1. Kaiten MCP: открыть точный документ проекта и метку карточки.
2. Если MCP недоступен — открыть уже авторизованный Kaiten в Chrome и прочитать
   тот же документ.
3. Если браузер недоступен — прочитать полный экспорт, положенный в рабочую
   папку приложения.
4. Если ни один источник не доступен — остановиться с `BLOCKED` и запросить у ПМ
   точное название/ссылку или экспорт. Не начинать реализацию.

### Источник дизайна

Сначала прочитать метку карточки Kaiten. Метка `no-code` означает согласованный
Claude Design/Pencil; без этой метки проект использует Figma.

Для Figma порядок такой:

1. Figma в браузере, где разработчик вошёл в аккаунт (computer use или браузер
   агента): спецификации — на панели свойств; проверь, какие фоны позже
   экспортировать в 6x. На preflight ничего не выгружай. MCP не нужен.
2. Экспортированные frames или приложенные скриншоты с однозначными названиями.
3. Если ни один вариант не доступен — `BLOCKED`. Нельзя заменять источник
   похожим дизайном, reference-приложением или собственной интерпретацией.

Для no-code-проекта нужен согласованный результат Claude Design/Pencil либо его
полный экспорт/скриншоты. Пустое поле Figma не доказывает `no-code`.

### Reference и backend

Reference ищется в документе Kaiten, доступных Git-репозиториях и live-проектах
компании. Он остаётся read-only. Если выбрать его однозначно нельзя, preflight
останавливается и просит решение тимлида-разработчика или ПМ.

Если backend уже работает в другом приложении компании, зафиксируй commit SHA
его референсного репозитория. Проследи фактические endpoint builders, auth и
refresh, DTO, загрузки, генерации, polling, баланс и подтверждение начислений.
В отчёте preflight составь таблицу:

| Функция | Method/path | Request/response | Auth | Ошибки/лимиты/retry/idempotency | Источник | Статус подтверждения | Компонент платформы |
|---|---|---|---|---|---|---|---|

Отдельно перечисли старую архитектуру, обходы и хардкод, которые не переносим.
Сверь найденное с OpenAPI и доступными проверками backend: код референса сам по
себе не подтверждает актуальный контракт. Расхождения сохрани с источниками и
запроси решение владельца backend. Неизвестный endpoint не заменяй fixture.
Preflight не создаёт и не изменяет файлы.

Спроси только то, чего нет в источниках: какой backend и окружение назначены
новому приложению, общий инстанс или новый, как разделены аккаунты, данные и
кредиты; какой референс/ветка актуальны, есть ли OpenAPI и кто подтверждает
расхождения; какие функции нужны, какой первый срез (онбординг с пейволом или
основная функция) и его кадры Figma; как проверять генерации и начисления
(тестовый аккаунт, кредиты, разрешённые операции, admin-доступ или выдача
кредитов разработчиком); готовы ли данные Adapty и какое приложение выбрано
разработчиком для `TEMPORARY` (оно может отличаться от backend-референса).
Секреты передаются отдельно, вне git, приложения и отчётов.

Backend считается изученным только после сопоставления функций с method/path,
request/response, обязательными полями, auth, ошибками, лимитами и retry.
Неподтверждённую ручку нельзя реализовать в зависимом срезе.

Если нужен RU Billing, monetization preflight отдельно фиксирует:

- production-значение `ru_pay` в Adapty и владельца Dashboard;
- backend catalog/checkout/authorization и финальный kill switch;
- нужен ли Dashboard-generated fallback для first-launch offline;
- что Debug force-on/off — только тест UI, а не production configuration.

Отсутствие доступа к Dashboard/backend даёт `Monetization: BLOCKED`, а не
разрешение зашить `ru_pay = true` в Swift.

### Support и legal

Preflight проверяет источник support address, Privacy Policy/Terms HTTPS URLs
и владельца каждого отсутствующего решения. Неизвестное значение получает
`Support/legal: BLOCKED`; `N/A` допустим только для явно исключённой области.
Агент не копирует support/legal данные из reference по сходству.

## Обязательный отчёт

До app-кода агент возвращает эти строки с коротким пояснением:

```text
Platform source: READY / BLOCKED — <URL, COMMIT SHA, PLATFORM_SET>
Kaiten: READY / BLOCKED
Design source: READY / BLOCKED
Reference: READY / BLOCKED / N/A
Backend: READY / PARTIAL / BLOCKED
Monetization: READY / BLOCKED / N/A
Support/legal: READY / BLOCKED / N/A
Можно создать безопасный каркас: ДА / НЕТ
Можно реализовать все обязательные функции: ДА / НЕТ
```

Каркас допустим, когда известны app identity, platform source и базовые
архитектурные решения. `Можно реализовать все обязательные функции: ДА`
допустимо только после доказанных screen/backend/product contracts. Для каждого
`BLOCKED` указываются конкретный материал, место проверки, ответственный и
независимая работа, которую можно продолжить.

## Готовый preflight prompt

Замените только значения в угловых скобках:

<!-- AGENT_PREFLIGHT_PROMPT:START -->
```text
Проведи preflight текущего iPhone-приложения на BroadApps iOS Platform.

Проект: <НАЗВАНИЕ ИЛИ ИДЕНТИФИКАТОР>.
Kaiten: <ССЫЛКА / ТОЧНОЕ НАЗВАНИЕ / ЭКСПОРТ>.
Reference: <ССЫЛКА / ЛОКАЛЬНЫЙ ПУТЬ / НАЙДИ>.
Backend/OpenAPI: <ССЫЛКА / НЕТ>.
Platform repository: https://github.com/BroadApps-official/broad-platform-integration.

Пока не создавай и не изменяй файлы приложения.

1. Из HOST REPOSITORY прочитай AGENTS.md/CLAUDE.md и README.md.
2. Из canonical PLATFORM REPOSITORY прочитай
   Documentation/AgentPreflight.md, Documentation/AppCreationWorkflow.md и
   Compatibility/current.yml. Верни фактически прочитанные commit SHA и
   platform_set. Если источник недоступен — остановись с
   Platform source: BLOCKED; private BroadCore не используй как замену.
3. Для Kaiten попробуй по порядку: Kaiten MCP; авторизованный Kaiten в Chrome;
   полный экспорт из рабочей папки. Если ничего нет — остановись с BLOCKED.
4. Определи тип дизайна только по метке Kaiten. Для Figma открой её в браузере,
   где разработчик вошёл (computer use/браузер агента): спецификации читай на панели
   свойств, отметь фоны для экспорта в 6x позже (скилл `broadapps-figma` из
   AgentKit); MCP не нужен. Сейчас файлы не выгружай.
   Если браузера нет — экспортированные frames/скриншоты. Для
   no-code открой согласованный Claude Design/Pencil или его экспорт. Если
   источник не виден — BLOCKED; не придумывай похожий интерфейс.
5. Найди reference в Kaiten, доступных Git-репозиториях или live-проектах.
   Не изменяй его, зафиксируй commit SHA. При неоднозначности запроси решение
   тимлида или ПМ.
6. Для любого backend сопоставь функции с method/path, request/response,
   обязательными полями, auth, ошибками и retry. Если backend работает в
   reference, проследи endpoint builders, auth/refresh,
   DTO, загрузки, генерации, polling, баланс и подтверждение начислений.
   Верни таблицу: функция → method/path → request/response → auth →
   ошибки/лимиты/retry/idempotency → источник → статус подтверждения → компонент
   платформы. Отдельно укажи старую архитектуру, обходы и хардкод, которые не
   переносим. Сверь с OpenAPI и доступными проверками backend: код reference
   сам по себе не подтверждает контракт. Расхождения передай владельцу backend.
   Спроси только неизвестное: backend и окружение нового приложения (инстанс
   общий или новый, разделение аккаунтов/данных/кредитов); актуальные reference
   и ветку, OpenAPI и владельца расхождений; переносимые функции, первый срез
   (онбординг+пейвол или основная функция) и его кадры Figma; тестовый аккаунт,
   кредиты, разрешённые операции, admin-доступ или выдачу кредитов для проверки
   генераций и начислений; готовность Adapty и выбранное приложение для TEMPORARY.
   Секреты — отдельно, вне git, приложения и отчёта. Не придумывай endpoint.
7. Проверь monetization decisions. Метка «Жду аккаунт» (нет ключа Adapty,
   продуктов, PP/ToU): спроси разработчика, данные какого похожего приложения
   компании взять (с теми же экранами, например токенами), сам не выбирай; пометь их
   `TEMPORARY` с источником и условием замены до выпуска. Разрешены только данные
   Adapty, Debug-продуктов и legal, не серверные секреты и production URL.
   Продукты образца переносятся в Debug `.storekit`
   все, с ценами App Store. Для RU Billing запиши `ru_pay` из Adapty,
   backend kill switch и необходимость Dashboard fallback. Не создавай
   Release-default для флага.
8. Проверь support/legal: источник support address, Privacy Policy/Terms URLs и
   владелец каждого отсутствующего решения. Не придумывай значения.
9. Верни ровно этот статус и короткие доказательства:

Platform source: READY / BLOCKED — <URL, COMMIT SHA, PLATFORM_SET>
Kaiten: READY / BLOCKED
Design source: READY / BLOCKED
Reference: READY / BLOCKED / N/A
Backend: READY / PARTIAL / BLOCKED
Monetization: READY / BLOCKED / N/A
Support/legal: READY / BLOCKED / N/A
Можно создать безопасный каркас: ДА / НЕТ
Можно реализовать все обязательные функции: ДА / НЕТ

Затем добавь [BLOCKED], чего именно нет, где это проверено, у кого запросить и
какую независимую работу можно продолжить. Не создавай код.
```
<!-- AGENT_PREFLIGHT_PROMPT:END -->

Следующий шаг после preflight — создать на этапе плана
`Documentation/AppIntegrationPlan.md` по
[`Templates/AppIntegrationPlan.md`](Templates/AppIntegrationPlan.md) и, для
референсного backend, `Documentation/BackendContract.md`. Полный порядок
находится в [App Creation Workflow](AppCreationWorkflow.md).

## Что запрещено считать успехом

- Kaiten URL есть, но содержимое не прочитано.
- Figma открывает страницу доступа, а не нужные frames.
- Скриншоты не позволяют сопоставить все экраны и состояния.
- Reference выбран «по названию» без проверки продуктового поведения.
- Backend перечислен общими словами без контрактов.
- Отсутствующая функция молча удалена из scope.

## Резерв RU при недоступном Adapty — 1.5.0

[Правило, подключение и проверки](RUProviderFallback.md): нет ответа Adapty или
не загрузились его продукты + RU Storefront **или** регион iPhone → свежий backend,
если разработчик явно подключил новый loader. Полученный false/invalid/absent
резерв запрещает; запрет сохраняется даже после ошибки продуктов. Старые API
остаются прежними. Кеш не превращается в свежий ответ; сервер подтверждает оплату.
