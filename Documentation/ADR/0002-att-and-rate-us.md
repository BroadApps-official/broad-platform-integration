# ADR-0002: ATT и Rate Us в onboarding

- Статус: принято
- Дата: 2026-08-09

## Контекст

ATT и запрос оценки приложения — разные системные сценарии. Их ранний вызов из loader/onboarding ухудшает первый запуск и создаёт риск отклонения приложения при review. При этом отдельный Rate Us flow вне onboarding остаётся допустимой продуктовой функцией.

## Решение

### ATT

ATT никогда не является bootstrap-шагом и не вызывается из loader, AppFlow coordinator или paywall.

Запрос может начаться только когда одновременно истинны условия:

1. onboarding находится на экране;
2. первый слайд фактически появился;
3. первый слайд остаётся текущим;
4. scene имеет состояние active;
5. SwiftUI view прикреплена к видимому `UIWindow`;
6. прошла app-configured delay;
7. системный status остаётся `.notDetermined`.

`OnboardingViewModel` держит максимум одну ожидающую задачу, отменяет её при потере любого условия и не создаёт повторную системную попытку в той же сессии.

Default `OnboardingTrackingAuthorizationPolicy` — `.disabled`. Для `.afterFirstSlide` host обязан предоставить локализованный `NSUserTrackingUsageDescription`.

`AppTrackingTransparency` импортируется только в `SystemTrackingAuthorizationAdapter`; UI зависит от use-case protocol.

### Rate Us

- Rate Us screen разрешён вне onboarding: например, settings/main или отдельный app-specific flow.
- Системный review API разрешён только через dedicated ReviewAdapter.
- Внутри onboarding запрещены Rate Us slide, review CTA и native review prompt.
- Отсутствие Rate Us в onboarding не означает запрет feature во всём приложении.

## Последствия

Положительные:

- loader никогда не зависает из-за системного permission prompt;
- пользователь видит контекст приложения до ATT;
- prompt не запускается под неактивным/невидимым окном;
- onboarding остаётся предсказуемым для review;
- Rate Us остаётся доступным в подходящем месте приложения.

Цена решения:

- onboarding должен сообщать visibility/scene state ViewModel;
- host обязан локализовать plist purpose string;
- app-specific Rate Us требует отдельного adapter/flow.

## Отклонённые варианты

### ATT в bootstrap/loader

Отклонён: системный UI становится скрытой startup-зависимостью и нарушает момент запроса.

### ATT сразу при создании onboarding ViewModel

Отклонён: объект может быть создан до появления view/window.

### Rate Us на последнем onboarding-слайде

Отклонён: review prompt является частью first-run coercion и запрещён проектным правилом.

### Полный запрет Rate Us

Отклонён: требование относится только к onboarding, а не к settings/main flow.

## Проверка решения

- launch/loader не показывает ATT;
- первый onboarding slide уже виден до prompt;
- background/inactive/невидимое окно отменяет ожидание;
- возврат на первый slide не создаёт второй системный запрос после попытки;
- `.disabled` не обращается к ATT adapter;
- onboarding source не содержит review API;
- Rate Us вне onboarding работает через отдельный app adapter.

Подробная инструкция: [Onboarding & ATT](../OnboardingAndATT.md).
