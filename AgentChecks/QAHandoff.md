# QA handoff: BroadApps iOS Platform и BroadAppTemplate

Дата: 2026-08-23. Этот пакет передаёт проверяемую платформу/template и отдельно
фиксирует, почему приложение 5135 Seedance ещё нельзя передавать QA.

## 1. Что готово

- Swift Package: `BroadCore`, `BroadMonetization`, `BroadUIFlows`,
  `BroadExtensions`.
- Example project: `Examples/BroadAppTemplate/BroadAppTemplate.xcodeproj`.
- Scheme: `BroadAppTemplate`, iPhone only, iOS 17+.
- Debug Simulator app после локальной сборки:
  `.build/DerivedData/Build/Products/Debug-iphonesimulator/BroadAppTemplate.app`.
- Release Simulator и generic iOS device собираются без подписи полным gate.
- Фактическая acceptance-матрица:
  [`TemplateAcceptanceReport.md`](TemplateAcceptanceReport.md).

Это не подписанный IPA и не сборка 5135.

## 2. Карта экранов template

| Entry point | Ожидаемый экран / результат |
|---|---|
| Default clean launch | Onboarding; ATT только после фактически видимого первого слайда |
| Main | Статус bootstrap, баланс токенов и безопасный каталог девяти карточек |
| Основной flow | Onboarding → initial paywall policy → main |
| Subscription paywall | Fixture-каталог subscription; premium только после подтверждённого entitlement |
| Token paywall | Отдельные consumables, backend confirmation/retry/recovery, без выдачи premium |
| Special offer | Опциональный второй paywall после close; unavailable ведёт в main |
| RU Billing | Безопасный выбор метода; настоящая оплата не запускается |
| Loader и ошибки | Немедленный spinner, disabled double tap, error и Retry |
| Аналитика | Только typed fixture-события текущего процесса |
| Contact Us | Composer на поддерживаемом устройстве либо Copy/Close fallback |
| Debug-хранилища | Независимые app-owned Keychain/flow/cache/analytics scopes |

## 3. Сценарии и ожидаемые результаты

Нормативные launch arguments и действия находятся в
[`Documentation/TemplateAcceptance.md`](../Documentation/TemplateAcceptance.md),
а фактически выполненный результат — в
[`TemplateAcceptanceReport.md`](TemplateAcceptanceReport.md). В частности
проверены:

- onboarding 1/2/3/4/8 страниц, custom/disabled/invalid;
- initial paywall once/every cold launch/disabled;
- entitlement active/inactive/unknown/timeout/StoreKit fallback;
- special offer absent/false/true/main fallback/platform cache/timer/no loop;
- token credited/pending/retry/cancel/provider failure/backend failure/offline/
  reconciliation/recovery и `.tokens → .main`;
- все девять карточек на маленьком и большом iPhone Simulator.

## 4. Безопасные ограничения QA

Запрещено в рамках этой приёмки:

- подтверждать настоящий Apple purchase или restore;
- запускать настоящий СБП/карточный checkout;
- менять Adapty, App Store Connect, Remote Config или backend dashboard;
- переносить signing team, bundle, provisioning, credentials, keys,
  certificates, backend auth или account data из reference;
- добавлять тестовые аккаунты, токены или секреты в Git/отчёт.

Для UI и state-machine используются только fixture-сценарии. Live Adapty
configuration проверяется сборкой/load contract без финансового действия.

## 5. Результаты проверок

| Область | Статус | Доказательство |
|---|---|---|
| Functional template | PASS | [`TemplateAcceptanceReport.md`](TemplateAcceptanceReport.md) |
| Midpoint audit | PASS после исправлений | [`MidpointAudit.md`](MidpointAudit.md) |
| Security/privacy platform | PASS | [`SecurityPrivacyReview.md`](SecurityPrivacyReview.md) |
| Visual self-review Simulator | PASS после layout fix | [`SelfReview.md`](SelfReview.md) |
| Debug/Release/generic device build | Подтверждается последним full gate | [`STATUS.md`](STATUS.md) |
| Physical iPhone acceptance | BLOCKED: signing team не выбрана | [`PhysicalDeviceReport.md`](PhysicalDeviceReport.md) |
| Независимый cold-read README новым человеком | HANDOFF | Дать разработчику только корневой README и записать замечания |

## 6. Известные ограничения

- Template использует собственную фиксированную тёмную palette; light theme не
  заявлена.
- На маленьком iPhone часть длинного token-каталога доступна прокруткой; главное
  действие остаётся видимым, текст выбранных строк не обрезается.
- Системный `MFMailComposeViewController`, VoiceOver и крупный Dynamic Type
  требуют подписанной установки на физический iPhone.
- Screenshot evidence находится в ignored `.build/Acceptance` и не коммитится.

## 7. Статус 5135 Seedance

`NOT READY / BLOCKED`. Platform PASS нельзя переносить на приложение 5135.
Приложение ещё не создано: нет Git/local project, ТЗ, reference, точного Figma
frame context и versioned backend API contracts. Детали и владельцы действий:

- [`Project5135Preflight.md`](Project5135Preflight.md);
- [`Project5135ExecutionStatus.md`](Project5135ExecutionStatus.md).

После снятия blocker-ов preflight выполняется заново до строки
`Можно начинать: ДА`; только затем нужны отдельные functional, visual,
configuration, device, security и developer-self-review доказательства самого
5135.

## 8. Что должен сделать принимающий разработчик

1. Запустить `bash Scripts/agent_gate.sh` после своих platform-изменений.
2. Открыть example, пройти нужные fixture-сценарии по acceptance checklist.
3. Выбрать app-owned signing team и проверить device-only пункты без платежей.
4. Для реального приложения заполнить
   [`Documentation/ProjectDelivery.md`](../Documentation/ProjectDelivery.md).
5. Передавать credentials и тестовые аккаунты только разрешённым защищённым
   каналом, отдельно от Git.
