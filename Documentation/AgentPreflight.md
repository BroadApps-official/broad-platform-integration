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

1. Figma MCP.
2. Авторизованная Figma в Chrome.
3. Экспортированные frames или приложенные скриншоты с однозначными названиями.
4. Если ни один вариант не доступен — `BLOCKED`. Нельзя заменять источник
   похожим дизайном, reference-приложением или собственной интерпретацией.

Для no-code-проекта нужен согласованный результат Claude Design/Pencil либо его
полный экспорт/скриншоты. Пустое поле Figma не доказывает `no-code`.

### Reference и backend

Reference ищется в документе Kaiten, доступных Git-репозиториях и live-проектах
компании. Он остаётся read-only. Если выбрать его однозначно нельзя, preflight
останавливается и просит решение тимлида-разработчика или ПМ.

Backend считается изученным только после сопоставления функций с method,
endpoint, request, response, обязательными полями, авторизацией, ошибками и
retry. Отсутствующую ручку нельзя придумывать или заменять локальным fixture в
production flow.

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
4. Определи тип дизайна только по метке Kaiten. Для Figma попробуй Figma MCP;
   авторизованную Figma в Chrome; экспортированные frames/скриншоты. Для
   no-code открой согласованный Claude Design/Pencil или его экспорт. Если
   источник не виден — BLOCKED; не придумывай похожий интерфейс.
5. Найди reference в Kaiten, доступных Git-репозиториях или live-проектах.
   Reference не изменяй. При неоднозначности запроси решение тимлида или ПМ.
6. Сопоставь функции с backend: method, endpoint, request, response,
   обязательные поля, auth, ошибки и retry. Не придумывай endpoint.
7. Проверь monetization decisions. Для RU Billing запиши `ru_pay` из Adapty,
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

Следующий шаг после preflight — создать только
`Documentation/AppIntegrationPlan.md` по
[`Templates/AppIntegrationPlan.md`](Templates/AppIntegrationPlan.md). Полный
порядок находится в [App Creation Workflow](AppCreationWorkflow.md).

## Что запрещено считать успехом

- Kaiten URL есть, но содержимое не прочитано.
- Figma открывает страницу доступа, а не нужные frames.
- Скриншоты не позволяют сопоставить все экраны и состояния.
- Reference выбран «по названию» без проверки продуктового поведения.
- Backend перечислен общими словами без контрактов.
- Отсутствующая функция молча удалена из scope.
