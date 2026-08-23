# QA handoff: BroadApps iOS Platform и BroadAppTemplate

Дата: 2026-08-23. Этот пакет передаёт проверяемую платформу/template. Он не
является отчётом какого-либо конкретного приложения.

## 1. Что готово

- Swift Package: `BroadCore`, `BroadMonetization`, `BroadUIFlows`,
  `BroadExtensions`.
- Example project: `Examples/BroadAppTemplate/BroadAppTemplate.xcodeproj`.
- Scheme: `BroadAppTemplate`, iPhone only, iOS 17+.
- Debug/Release Simulator и generic `iphoneos` compile без подписи.
- Фактическая acceptance-матрица:
  [`TemplateAcceptanceReport.md`](TemplateAcceptanceReport.md).

Подписанный `.ipa`, provisioning и выбор Signing Team не входят в этот handoff.

## 2. Карта экранов template

| Entry point | Ожидаемый экран / результат |
|---|---|
| Default clean launch | Onboarding; ATT только после видимого первого слайда |
| Main | Bootstrap, баланс токенов и каталог девяти карточек |
| Основной flow | Onboarding → initial paywall policy → main |
| Subscription paywall | Fixture subscriptions; premium только после entitlement |
| Token paywall | Consumables, backend confirmation/retry/recovery, без premium |
| Special offer | Subscription paywall → крестик без покупки → resolver → optional второй paywall; confirmed purchase/restore обходит offer |
| RU Billing | Безопасный выбор метода; настоящая оплата не запускается |
| Loader и ошибки | Немедленный spinner, disabled double tap, error и Retry |
| Аналитика | Общий recorder, видимый refresh и clear feedback |
| Contact Us | Composer, если доступен, либо Copy/Close fallback |
| Debug-хранилища | Независимые Keychain/flow/cache/analytics scopes |

## 3. Сценарии и ожидаемые результаты

Нормативные arguments и действия находятся в
[`Documentation/TemplateAcceptance.md`](../Documentation/TemplateAcceptance.md),
а фактический результат — в
[`TemplateAcceptanceReport.md`](TemplateAcceptanceReport.md). Проверены:

- onboarding 1/2/3/4/8 страниц, custom/disabled/invalid;
- initial paywall once/every cold launch/disabled;
- entitlement active/inactive/unknown/timeout/StoreKit fallback;
- special offer absent/false/true/main fallback/platform cache/timer/no loop;
- token credited/pending/retry/cancel/failure/offline/reconciliation/recovery;
- все девять карточек на маленьком и большом iPhone Simulator.

## 4. Безопасные ограничения QA

В рамках platform/template приёмки запрещено:

- подтверждать настоящий Apple purchase или restore;
- запускать настоящий СБП/карточный checkout;
- менять Adapty, App Store Connect, Remote Config или backend dashboard;
- переносить bundle, provisioning, credentials, keys, certificates, backend
  auth или account data из reference;
- добавлять тестовые аккаунты, токены или секреты в Git/отчёт.

Для UI и state-machine используются fixture-сценарии. Live Adapty
configuration проверяется compile/load contract без финансового действия.

## 5. Результаты проверок

| Область | Статус | Доказательство |
|---|---|---|
| Functional template | PASS | [`TemplateAcceptanceReport.md`](TemplateAcceptanceReport.md) |
| Midpoint audit | PASS после исправлений | [`MidpointAudit.md`](MidpointAudit.md) |
| Security/privacy platform | PASS | [`SecurityPrivacyReview.md`](SecurityPrivacyReview.md) |
| Visual self-review Simulator | PASS | [`SelfReview.md`](SelfReview.md) |
| Debug/Release/generic unsigned compile | Последний full gate | [`STATUS.md`](STATUS.md) |
| Любой host app | Отдельный app-level статус | [`ApplicationIntegrationContract.md`](ApplicationIntegrationContract.md) |

## 6. Известные ограничения

- Template использует собственную фиксированную тёмную palette; light theme не
  заявлена.
- На маленьком iPhone длинный token-каталог доступен прокруткой; главное
  действие остаётся видимым.
- Screenshot evidence находится в ignored `.build/Acceptance` и не коммитится.
- Компания может отдельно проверить сборку на iPhone своим способом; это
  дополнительное evidence, а не обязательный platform gate.

## 7. Что должен сделать принимающий разработчик

1. Запустить `bash Scripts/agent_gate.sh` после platform-изменений.
2. Открыть example и пройти нужные fixture-сценарии на двух Simulator.
3. Оставить `Team = None`; не запрашивать платный аккаунт или provisioning.
4. Для своего приложения заполнить
   [`Documentation/ProjectDelivery.md`](../Documentation/ProjectDelivery.md).
5. Передавать credentials и тестовые аккаунты только разрешённым защищённым
   каналом, отдельно от Git.
