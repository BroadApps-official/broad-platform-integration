# Правила для Codex в BroadApps iOS Platform

Этот файл обязателен для любого Codex-запуска из корня репозитория. Он задаёт
границы автоматической проверки и исправления платформы.

## Scope

- Работай только внутри `BroadAppsIOSPlatform`.
- По решению руководства Codex automation запускается с полным доступом к Mac,
  чтобы Xcode видел CoreSimulatorService. Полный доступ не разрешает менять
  файлы за пределами `BroadAppsIOSPlatform`.
- Не изменяй reference-проекты `5013`, `5109Codex`, `Claude232` и `Шаблон`.
- Не создавай `Tests`, test targets и код на XCTest/Swift Testing.
- Платформа и example — только для iPhone. Не добавляй iPad, Mac, Mac Catalyst
  или visionOS targets/configurations. Example обязан хранить
  `TARGETED_DEVICE_FAMILY = 1`.
- Рабочие public Adapty SDK configurations 5013/5109Codex должны оставаться в
  tracked source по требованию руководства. Не удаляй и не маскируй их.
- Backend credentials, private signing keys и токены серверного доступа сюда не
  добавляются.

## Обязательные продуктовые правила

- Архитектура: Clean Architecture + MVVM + SOLID; зависимости направлены внутрь.
- ATT никогда не вызывается в loader. Запрос разрешён только после фактического
  появления первого onboarding-слайда.
- Rate Us разрешён в приложении, но запрещён внутри onboarding.
- Конкретные Adapty placement ID задаёт host app; у любого placement есть резерв
  на логический `main`.
- Не фильтруй и не переупорядочивай продукты Adapty. UI обязан безопасно
  показывать любое количество продуктов, включая 0, 1 и дубликаты SKU.
- Нажатие на продукт paywall не должно давать затемнение, мерцание или
  стандартный press-effect.
- Special offer полностью опционален: отсутствие config не считается ошибкой.
- Purchase/restore не открывают premium до подтверждения entitlement.
- После переустановки subscription ownership восстанавливается через
  StoreKit/backend, а token balance и RU purchases — только через стабильный app
  account и server-authoritative ledger. Local cache не является источником
  купленного доступа или баланса.
- Offline/timeout не превращаются в inactive/success. Неопределённый финансовый
  результат остаётся pending до reconciliation; появление сети не запускает
  purchase, token charge, RU checkout или cancellation автоматически.
- Usedesk подключается только когда он нужен конкретному приложению. Готовый GUI
  устанавливается через CocoaPods в app target и открывается только действием
  `Настройки → Онлайн-чат`, не в loader/bootstrap. Для обычного чата
  `api_token` остаётся `nil`; user chat token хранится на backend текущего app
  account при `isSaveTokensInUserDefaults = false`, чтобы история переживала
  переустановку и не смешивалась между аккаунтами.
- Любая кнопка, запускающая backend/SDK use case, синхронно переводит UI в
  `isInFlight` до создания `Task` и первого `await`: сразу показывает spinner и
  блокирует повторный тап до результата или безопасного перехода.
- Очистка Keychain разрешена только в Debug-настройках, после подтверждения и
  только для явно перечисленных app-owned service/access group. Release не
  содержит этот инструмент; payment pending этой кнопкой не очищается.
- Письмо в поддержку заполняется строго по `Documentation/SupportEmail.md`.
  Стандартная и RU/ЮKassa-формы отличаются только `(ukassa)` в первой строке;
  остальные заголовки и порядок полей не меняются. Support log очищается от
  токенов, payment URL, receipt/JWS и raw payload.

## Ограничения проверки

- Не выполнять настоящую покупку, restore или RU-платёж.
- Не требовать StoreKit sandbox: он недоступен по правилам компании.
- Не требовать VoiceOver/Dynamic Type matrix на физических устройствах.
- Не создавать archive, signed `.ipa` и host attestation.
- Live Adapty schemes разрешено только собирать. Не запускай финансовые SDK
  операции.

## Порядок автоматического исправления

На macOS вызывай поиск явно через `/opt/homebrew/bin/rg`, если этот файл
доступен. Временную копию `rg` из `codex-path` может блокировать Gatekeeper.
`Scripts/agent_gate.sh` сам ставит Homebrew path первым для всех вложенных
проверок.

1. Прочитай `README.md`, `AgentChecks/STATUS.md` и относящуюся к ошибке
   документацию.
2. Запусти `bash Scripts/agent_gate.sh`.
3. Если проверка упала, найди первопричину. Не отключай, не ослабляй и не обходи
   проверку ради зелёного результата.
4. Внеси минимальные правки только в platform-owned файлы. Для ручных правок
   используй `apply_patch`.
5. После изменения Swift-кода выполни `bash Scripts/format.sh`, затем снова
   запусти `bash Scripts/agent_gate.sh`.
6. Повторяй цикл до PASS либо до честно описанного внешнего блокера.
7. Никогда не запускай `Scripts/agent_review_and_fix.sh` изнутри агента: это
   создаст рекурсивный запуск.

## Финальный ответ агента

Пиши по-русски и простыми словами. Обязательно добавь разделы:

- `Итог` — PASS или BLOCKED;
- `Что проверил`;
- `Что нашёл`;
- `Что исправил` — либо явно «правки не потребовались»;
- `Изменённые файлы`;
- `Команды и результаты`;
- `Что осталось`;
- `Следующий шаг`.

В runtime-отчёте не используй абсолютные `/Users/...` пути: указывай файлы
относительно корня платформы.

Не утверждай PASS, если последний `bash Scripts/agent_gate.sh` завершился с
ошибкой. Ещё один независимый PASS после ответа добавляет wrapper.
