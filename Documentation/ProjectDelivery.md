# Подготовка конкретного приложения к QA

Этот checklist начинается после того, как платформа и `BroadAppTemplate` уже
прошли `bash Scripts/agent_gate.sh`. Он относится к конкретному приложению и не
позволяет подменить недоступные Kaiten, дизайн, backend или внешнюю
конфигурацию зелёной сборкой платформы.

До первого Swift-файла скопируйте
[`Templates/AppIntegrationPlan.md`](Templates/AppIntegrationPlan.md) в
repository приложения и заполните его по
[`AppCreationWorkflow.md`](AppCreationWorkflow.md). Функции реализуются по
одному вертикальному срезу; следующий срез начинается только после
`SLICE REVIEW REQUIRED` и проверки предыдущего разработчиком.

## Статусы

Для каждой строки используйте только один статус:

| Статус | Значение |
|---|---|
| `READY` | Проверено фактическим источником или воспроизводимым результатом |
| `BLOCKED` | Не хватает обязательного внешнего материала или решения; указан владелец следующего действия |
| `N/A` | Функция явно не входит в требования текущего приложения |

`TODO`, пустая ячейка и «должно работать» не разрешают передачу QA.

## 1. Паспорт входных материалов

Не записывайте сюда значения credentials. Достаточно источника, статуса и
ответственного.

| Материал | Статус | Источник | Что проверить | Кто снимает blocker |
|---|---|---|---|---|
| Карточка и документ Kaiten |  |  | Текущее приложение, метка `no-code`, заполненные поля | PM / account manager |
| Источник дизайна |  |  | Figma без `no-code`; Claude Design/Pencil при `no-code` | PM / designer |
| Reference |  |  | Выбран однозначно и используется только для чтения | Tech lead / PM |
| Backend-документация |  |  | Method, endpoint, request/response, auth, errors, retry | Backend owner |
| Тексты и assets |  |  | Актуальная версия и источник каждого экрана | Designer / PM |
| Legal URL и support email |  |  | Принадлежат текущему приложению | PM / legal |
| Монетизация |  |  | Subscriptions/tokens/RU/special offer и initial-paywall policy | Product / tech lead |
| Analytics requirements |  |  | События, destinations и запрещённые поля | Product / analytics owner |

Если обязательная строка `BLOCKED`, код, зависящий от неё, не выдаётся за
production-ready. Разрешён fixture или явный unavailable-state с описанным
blocker, но не выдуманный endpoint, дизайн или ключ.

## 2. Решения продукта до реализации

| Решение | Выбранный вариант | Доказательство |
|---|---|---|
| Onboarding | disabled / список реальных страниц | Kaiten + design source |
| Initial paywall | once / every cold launch while inactive / disabled | Product requirement |
| Premium | subscriptions / отсутствует | Monetization requirement |
| Tokens | нужны / не нужны | Entry point + backend fulfillment contract |
| Special offer | нужен / не нужен | Placement + current Remote Config contract |
| RU Billing | нужен / не нужен | Backend + legal + remote gate |
| `ru_pay` | `true` / `false`; владелец флага | Product decision + verified-fresh transport |
| RU freshness | Endpoint/schema/TTL/offline policy / `N/A` | Host repository sets `.verifiedFreshRemote` only for proven network origin |
| RU emergency off | Backend kill switch + `ru_pay = false` procedure | Backend/product owner |
| Contact Us | support email + standard/ukassa form | `SupportEmail.md` + app configuration |
| Account recovery | Apple / tokens / RU ownership sources | Authenticated balance endpoint; purchase IDs только для exactly-once fulfillment |
| Usedesk, если нужен | Backend chat-token source + Keychain cache/pending sync | Account scope; device ID не используется как identity |
| Offline | доступные функции и safe fallback | Backend/UX decision |

## 3. Backend-матрица

Одна строка на каждую функцию пользователя. Наличие SwiftUI-кнопки без этой
строки не означает подключённый backend.

| Функция | Method + endpoint | Request/response | Contract smoke | Auth | Errors/retry/offline | Код вызова | Статус |
|---|---|---|---|---|---|---|---|
| Пример: история | `GET /…` | Ссылка на schema | Production-shape fixture декодирован; missing-field даёт safe error; UI-поля сверены | App account | Timeout → Retry | Repository/use case | `READY/BLOCKED` |

В таблице можно указывать названия и ссылки на внутреннюю документацию, но не
секреты, bearer tokens или полный пользовательский payload.

`READY` требует воспроизводимый безопасный contract smoke по согласованному
обезличенному production-shape fixture или версионированной schema. Компиляция,
кнопка и happy-path fixture без проверки обязательных полей не считаются
подключённым backend.

## 4. Функциональная итерация

- [ ] Bootstrap имеет конечные timeout; optional шаги не блокируют первый экран.
- [ ] AppFlow использует утверждённую initial-paywall policy.
- [ ] `OnboardingConfiguration.pages` совпадает с реальным источником.
- [ ] Subscription и token paywall открываются только в своих местах.
- [ ] Token purchase использует `TokenPurchaseManager`; баланс меняется после backend.
- [ ] Обычный token recovery получает полный account balance без списка
      transaction/checkout ID; backend не начисляет один ID повторно.
- [ ] Active entitlement пропускает subscription paywall; unresolved не выдаёт premium.
- [ ] Special offer опционален и не включается platform cache.
- [ ] Special Offer никогда не открывается первым: крестик subscription paywall
  запускает resolver и только затем показывает offer/main; подтверждённая
  purchase/restore первого paywall обходит offer.
- [ ] Один analytics pipeline видит события subscription и special-offer презентаций.
- [ ] RU methods требуют verified-fresh разрешающий gate и app-owned backend.
- [ ] Release берёт `ru_pay` только из verified-fresh source; локальный force-on/off существует только в Debug.
- [ ] Debug force-on не обходит RU device context, catalog, backend authorization и entitlement.
- [ ] Adapty fallback не выдаётся за freshness proof RU Billing.
- [ ] Contact Us имеет composer и fallback.
- [ ] Backend/SDK кнопки сразу показывают spinner и блокируют double tap.
- [ ] Empty/error/offline/retry состояния видимы пользователю.
- [ ] Debug и Release собираются; Debug-инструменты отсутствуют в Release.
- [ ] Настоящие purchase, restore и RU checkout не выполнялись автоматизацией.

После заполнения этого раздела статус — `FUNCTIONAL REVIEW REQUIRED`.
Разработчик лично открывает сборку и письменно подтверждает переход к разделу 5.
Без подтверждения визуальная итерация не начинается.

## 5. Визуальная итерация

Для каждого обязательного экрана заполните строку. Каждый source state нужно
сверить минимум на маленьком и большом iPhone Simulator; если source задан для
конкретной модели, дополнительно используйте этот же размер.

| Экран/состояние | Source frame | Маленький iPhone | Большой iPhone | Проверены layout/type/color/assets/states | Итог |
|---|---|---|---|---|---|
| Onboarding |  |  |  |  | `READY/BLOCKED/N/A` |
| Main |  |  |  |  |  |
| Settings |  |  |  |  |  |
| Subscription paywall |  |  |  |  |  |
| Token paywall |  |  |  |  |  |
| Special offer |  |  |  |  |  |
| RU Billing |  |  |  |  |  |
| Loading/empty/error/offline |  |  |  |  |  |
| Contact Us |  |  |  |  |  |

Если frame недоступен, итог — `BLOCKED`, а не «похожий UI принят».

## 6. Simulator-first приёмка

- [ ] Маленький и большой iPhone Simulator проходят обязательные flow.
- [ ] Системный Mail composer либо documented Simulator fallback показывает
  правильный recipient/subject/body.
- [ ] `support-log.txt` сформирован и очищен по `SupportEmail.md`.
- [ ] ATT не появился в loader и был запрошен только после первого слайда.
- [ ] При отключённом onboarding ATT не запрашивался.
- [ ] Cold-launch policy сохранила ожидаемый маршрут.
- [ ] Длинные тексты и крупный шрифт не скрывают критические кнопки.
- [ ] Debug Status объясняет результат без Console; безопасный runtime-поток
  подтверждает ожидаемые `[BOOTSTRAP]`/`[FLOW]`/`[EXPERIMENTS]` события.

Оставьте `Team = None`: платный Apple Developer аккаунт, provisioning и
подписанная установка не входят в обязательную приёмку. Если компания отдельно
предоставляет способ проверить сборку на iPhone, результат можно добавить как
дополнительное app-level evidence. Отсутствие такой проверки не является
`BLOCKED` для платформы, template или checklist приложения.

## 7. Внешние конфигурации

Фиксируйте только факт и источник. Значения ключей и credentials в этот файл и
Git не добавляются.

| Конфигурация | Current app source | Debug/Release проверка | Статус |
|---|---|---|---|
| Bundle ID |  | Уникален для текущего приложения; `Team = None` |  |
| Adapty public SDK configuration |  | load/show only |  |
| Placements и entitlement ID |  |  |  |
| App Store Connect products |  | metadata only |  |
| Ожидаемые product ID |  | load/show payload, каждый ID найден/отсутствует |  |
| Remote Config |  | typed current payload |  |
| RU Billing backend |  | без реального checkout |  |
| Support/legal |  |  |  |
| Analytics destinations |  | safe typed events |  |

## 8. Security и privacy review

- [ ] В Git нет credentials, private keys и server access tokens.
- [ ] В Console нет email, receipt/JWS, payment URL и raw provider payload.
- [ ] Support log очищает чувствительные поля.
- [ ] Keychain cleaner знает только точные app-owned services.
- [ ] Payment pending не удаляется Debug-инструментами.
- [ ] Entitlement, token balance и RU ownership не выдаются обычным cache.
- [ ] Usedesk Keychain cache, если он есть, привязан к account; backend sync
      failure остаётся pending и не скрывается через `try?`.
- [ ] Privacy manifest соответствует фактически используемым API.
- [ ] Release не содержит Debug-каталог и destructive development actions.

## 9. Developer self-review

Разработчик лично проходит clean install, repeat launch, onboarding, все нужные
paywall, active/inactive/unresolved, offline/retry, background/foreground,
Contact Us, analytics и persistence на маленьком и большом iPhone Simulator.
Замечания исправляются до передачи QA.

## 10. Пакет передачи QA

Передайте вместе со сборкой:

- карту экранов и источники дизайна;
- список fixture-сценариев и launch arguments;
- заполненную acceptance-матрицу;
- ожидаемые premium/tokens/RU outcomes;
- известные ограничения и все `N/A`;
- внешние `BLOCKED`, если передача всё же согласована ответственным;
- тестовые аккаунты через разрешённый защищённый канал, не через Git;
- результаты Debug/Release, functional, visual, Simulator и security review;
- имя разработчика, выполнившего self-review.

QA не должен угадывать, где включается сценарий или какой результат считается
правильным.

## Финальный вердикт

Передача QA разрешена только когда обязательные строки имеют `READY`, допустимые
неиспользуемые функции — `N/A`, а каждый `BLOCKED` либо снят, либо письменно
принят ответственным за релиз. Platform gate остаётся обязательным после любого
изменения `BroadAppsIOSPlatform`, но не заменяет этот checklist.
