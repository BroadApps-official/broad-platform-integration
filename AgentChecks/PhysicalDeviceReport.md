# Проверка физического iPhone

Дата: 2026-08-23.

## Доступность

- `xcrun devicectl list devices` видит подключённый iPhone 15 Pro Max;
- `xcrun xctrace list devices` подтверждает физическое устройство с iOS 26.5;
- `BroadAppTemplate` настроен только для iPhone (`TARGETED_DEVICE_FAMILY = 1`);
- в example-проекте `DEVELOPMENT_TEAM` пустой.

## Статус

`BLOCKED` для установки и ручной приёмки на устройстве. Команда подписи не
выбиралась и provisioning state не изменялся: назначать team или создавать
профиль без решения владельца проекта нельзя.

После выбора signing team разработчику нужно вручную проверить:

- системный `MFMailComposeViewController`, recipient, subject/body и очищенный
  `support-log.txt`;
- fallback при недоступном Mail, Copy и возврат в приложение;
- ATT только после первого фактически видимого onboarding-слайда и отсутствие
  ATT в loader/disabled flow;
- once/every/disabled на настоящих cold launch;
- VoiceOver, requested/resolved placement и Accessibility Dynamic Type.

Эти пункты нельзя заменять Simulator PASS. Реальные purchase, restore и RU
checkout для них не требуются и по-прежнему запрещены.
