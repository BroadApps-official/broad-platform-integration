# Фактическая приёмка BroadAppTemplate

Дата прогона: 2026-08-23. Единственный нормативный checklist —
[`Documentation/TemplateAcceptance.md`](../Documentation/TemplateAcceptance.md).
Ниже записан фактический результат безопасного ручного прогона; наличие кода
или похожей кнопки само по себе не считалось доказательством.

## Окружение и границы

- маленький Simulator: `BroadTemplate Small iPhone`, iOS 18.6;
- большой Simulator: iPhone 17 Pro, iOS 26.2;
- bundle: `com.broadapps.platform.template`;
- scheme: `BroadAppTemplate`, Debug;
- реальные purchase, restore и RU checkout не запускались;
- fixture-progress маленького Simulator был очищен переустановкой только
  BroadAppTemplate перед повторной entitlement-проверкой.

## Каталог из девяти карточек

| Карточка | Маленький iPhone | Большой iPhone | Фактический результат |
|---|---|---|---|
| Основной flow | PASS | PASS | Экран открывается и закрывается; cold-launch аргументы проверены отдельно |
| Subscription paywall | PASS | PASS | Каталог и close доступны; финансовое действие не запускалось |
| Token paywall | PASS | PASS | Открывается отдельный consumable UI, не subscription UI |
| Special offer | PASS | PASS | Открывается общий paywall с источником `SPECIAL OFFER`; close возвращает в каталог |
| RU Billing | PASS | PASS | Безопасный fixture открывается; настоящий checkout не запускался |
| Loader и ошибки | PASS | PASS | Spinner появляется до ответа, кнопка сразу disabled, повторный tap заблокирован, результат находится в той же секции |
| Аналитика | PASS | PASS | Экран, refresh/clear и понятное empty-состояние доступны; отображаются только typed fixture-события |
| Contact Us | PASS | PASS | Simulator показывает fallback без пустого экрана; Copy и Close доступны |
| Debug-хранилища | PASS | PASS | Четыре независимых scope и отдельные результаты; destructive финансовые pending-состояния не очищаются |

На обоих размерах у карточек есть понятный возврат. Основные заголовки,
длинные описания и нижние действия оставались читаемыми; видимого наложения или
обрезки обязательного действия не обнаружено.

## AppFlow

| Сценарий | Аргументы / действие | Фактический UI | Результат |
|---|---|---|---|
| 1 страница | `-onboarding-one-page -tracking-disabled` | `Прогресс онбординга: 1 / 1`, `Смотреть тарифы` | PASS |
| 2 страницы | `-onboarding-two-pages -tracking-disabled` | `1 / 2`, `Продолжить` | PASS |
| 3 страницы | `-onboarding-three-pages -tracking-disabled` | `1 / 3`, `Продолжить` | PASS |
| 4 страницы | `-onboarding-four-pages -tracking-disabled` | `1 / 4`, `Продолжить` | PASS |
| Много страниц | `-onboarding-long -tracking-disabled` | `1 / 8`, нижнее действие доступно | PASS |
| Custom UI | `-onboarding-custom-ui -tracking-disabled` | App-owned onboarding и `Продолжить` | PASS |
| Отключён | `-onboarding-disabled -tracking-disabled` | Onboarding отсутствует, открывается initial paywall | PASS |
| Invalid | `-onboarding-invalid -tracking-disabled` | Пустой onboarding пропущен без зависания и ATT, открывается paywall | PASS |
| Once | invalid fixture: close paywall, затем cold launch | В той же установке повторный launch ведёт в main | PASS |
| Every cold launch | `-initial-paywall-every-cold-launch` | После close — main в текущей сессии; после нового process launch — paywall | PASS |
| Disabled policy | `-initial-paywall-disabled` | Сразу main | PASS |
| Active | `-app-flow-paywall-only -entitlement-active` | Main, subscription paywall пропущен | PASS |
| Inactive | `-app-flow-paywall-only -entitlement-inactive` | `Выберите тариф` | PASS |
| Unknown | `-app-flow-paywall-only -entitlement-unknown` | Main без ложного premium | PASS |
| Timeout | `-app-flow-paywall-only -entitlement-timeout` | Main без преобразования timeout в active/inactive | PASS |
| StoreKit fallback | `-app-flow-paywall-only -entitlement-store-kit-fallback` | Main по подтверждённому StoreKit fixture | PASS |

Первый черновой entitlement-прогон был намеренно отброшен: общий сохранённый
fixture-checkpoint искажал маршрут `inactive`. После чистой установки проверка
повторена с `-app-flow-paywall-only`, который даёт отдельный namespace каждому
entitlement fixture; таблица содержит только этот повторный результат.

## Special offer

| Сценарий | Фактический результат | Статус |
|---|---|---|
| Конфигурация отсутствует | Close initial paywall ведёт в main без ошибки | PASS |
| `special_offer = false` | Offer не открывается, main доступен | PASS |
| `special_offer = true` | После close открывается второй paywall с `SPECIAL OFFER` | PASS |
| Fallback на `main` | Offer открывается, исходный сценарий не теряется | PASS |
| Platform cache | Сохранённый platform cache не включает offer | PASS |
| Таймер | Видимое значение стартует с `00:02:59` | PASS |
| Повторное закрытие | Close offer ведёт в main | PASS |
| Нет бесконечного показа | Следующий cold launch того же once-fixture остаётся на main | PASS |

## Token flow

Начальный подтверждённый backend balance fixture — `120`.

| Сценарий | Фактический результат | Статус |
|---|---|---|
| Обычное зачисление | `100` токенов: balance `120 → 220` только после backend confirmation | PASS |
| Pending | `500`: balance остаётся `220`, появляется `Повторить подтверждение` | PASS |
| Pending retry | Reconciliation даёт `220 → 720`; нового purchase-start для того же evidence нет | PASS |
| Отмена | `900`: `Покупка отменена`, balance остаётся `720` | PASS |
| Provider failure | `1 200`: ошибка до списания, balance остаётся `720` | PASS |
| Backend failure | `2 000`: первый ответ не меняет balance; retry даёт `720 → 2720` | PASS |
| Offline | `5 000`: сохранённое evidence, balance остаётся `2720` | PASS |
| Reconciliation | Retry без второго charge даёт `2720 → 7720` | PASS |
| Восстановление | Backend account ledger возвращает подтверждённый `7720` | PASS |
| `.tokens → .main` | Accessibility: `requested=tokens;resolved=main`; UI остаётся consumable | PASS |
| Нет premium | После fixture-зачислений экран остаётся token UI, close возвращает в обычный main | PASS |
| Идемпотентность | Повторное fulfillment одного pending evidence начисляет один раз; аналитика показывает reconciliation, не новую покупку | PASS |

Все token-операции были локальными fixture-вызовами. Системный StoreKit sheet,
настоящая оплата и настоящий backend не использовались.

## Итог этапа

`PASS` для ручной приёмки BroadAppTemplate на двух Simulator. Проверки,
которые по природе требуют физический iPhone или входы конкретного продукта,
в этот результат не включены и отслеживаются отдельно.
