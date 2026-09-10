# Проверить платформу или приложение

Одна команда запускает одного reviewer. Он читает фактический код и возвращает
замечания с файлами, причинами и необходимыми исправлениями. SwiftFormat,
SwiftLint, module gates и сборки дополняют этот аудит.

## Проверить платформу

Рядом с integration checkout должны лежать `broad-core-ios`,
`broad-extensions-ios`, `broad-monetization-ios` и `broad-ui-flows-ios`.
Список владельцев берётся из `Compatibility/current.yml`, каждый checkout
проверяется по `ModuleContract.json`. Отсутствующий модуль не пропускается.

Из корня integration:

```bash
bash Scripts/agent_review_and_fix.sh platform --doctor
bash Scripts/agent_review_and_fix.sh platform
```

Если модули лежат в другой папке, добавьте `--modules-root "/path/to/modules"`.
Команда не клонирует и не обновляет repositories автоматически.
Проверяются четыре локальных module gate, затем integration gate.
Integration собирает версии из каталога: его PASS сам по себе не подтверждает
совместимость новых локальных изменений модулей. Их принятие и выпуск идут по
[release policy](ModuleReleasePolicy.md).

## Проверить приложение

Платформа служит источником правил; рабочая цель — папка приложения:

```bash
bash Scripts/agent_review_and_fix.sh app "/path/to/MyApp" --scheme MyApp --doctor
bash Scripts/agent_review_and_fix.sh app "/path/to/MyApp" --scheme MyApp
```

Для единственного проекта и единственной shared scheme имя выбирается
автоматически. При нескольких/вложенных проектах добавьте
`--project "App/MyApp.xcodeproj"` или путь `.xcworkspace` относительно app root.
Готовый workspace имеет приоритет перед одиночным project.
Папка должна находиться в Git; незакоммиченные изменения сохраняются.

Wrapper выполняет Debug/Release для Simulator и Release для generic iOS без
подписи. Агент отдельно сверяет шесть областей:

| Область | Что проверяется |
|---|---|
| reuse | Реальные вызовы общих компонентов, параллельные менеджеры, версии и копии логики |
| placements | Текущий placement, отсутствующие ключи main, token/tokens, products и A/B attribution |
| async_ui | Loader до Task/await, double tap, пустой каталог, ошибка, retry, pending и foreground |
| onboarding | Общие pages/lifecycle, ATT после видимого слайда, disabled и Rate Us |
| payments | Подтверждение доступа, единый operation gate, RU backend, tokens и special offer |
| style | Формат, lint, SDK boundary, зависимости экрана, безопасные ошибки и логи |

Отдельный app bridge или свой экран не считаются ошибкой автоматически.
Reviewer различает устаревшую версию, неверное подключение и возможность,
которой нет даже в актуальном модуле. Для отсутствующей функции допускается
N/A с объяснением. Неизвестный backend не выдумывается.

## Исправления и запуск внутри открытого агента

Явные режимы `platform` и `app` выполняют только аудит. Добавьте `--fix`, чтобы
разрешить минимальные исправления выбранных repositories. После ответа агента
wrapper повторяет независимые проверки. Большая миграция и новые продуктовые
решения остаются отдельной задачей. Автоматических commit/push нет.

Старые команды без аргументов и с `run` сохраняют исправление платформы; для
понятной границы используйте явный режим. В один момент запускается одна
проверка каждой цели. Полный доступ к Mac нужен Xcode; границы правок заданы
инструкцией, это не filesystem sandbox. При изменении исходников во время
аудита wrapper возвращает BLOCKED и ничего не откатывает.

Из уже работающего Codex/Claude не запускайте wrapper рекурсивно. Прочитайте
`AgentChecks/AUTOMATION_PROMPT.md` и выполните аудит в текущей сессии. Получить
готовый контекст без агента и сборок можно через `--print-prompt`.

## Где результат

В выбранной папке: `.build/AgentReview/platform/` или `.build/AgentReview/app/`.
`latest.md` содержит итог и SHA исходников, `response.json` — структурированный
ответ, `before-*.log` и при исправлениях `after-*.log` — независимые проверки.
Отчёты приложений остаются локальными, не публикуются на сайте или в platform
AgentChecks. Исторический файл `AgentChecks/AutomationReports/latest.md` не
перезаписывается и не считается текущим результатом.

| Итог / exit code | Значение |
|---|---|
| PASS / 0 | В scope аудита нет открытых замечаний, независимые проверки прошли |
| ISSUES / 1 | Найдены подтверждённые нарушения стандарта |
| BLOCKED / 2 | Проверка/сборка невозможна, отчёт неполон или нарушена граница аудита |

Зелёная сборка не отменяет ISSUES/BLOCKED. Проверка не подтверждает настоящие
платежи, внешний backend и соответствие Figma. Юнит-тесты и test targets не
создаются. Доступные локальные сценарии проверяются по
[приёмке template](TemplateAcceptance.md) и [handoff приложения](ProjectDelivery.md).

Нужны macOS, Xcode, Git, ripgrep и авторизованный Codex CLI с `--output-schema`.
Wrapper использует системный Ruby без дополнительных gem.
Флаги CLI сверены с [официальной документацией OpenAI](https://developers.openai.com/codex/noninteractive)
и установленным `codex exec --help`.
