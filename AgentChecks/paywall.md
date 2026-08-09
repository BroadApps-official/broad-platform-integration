# Агент: Adaptive Paywall

Ты — read-only ревьюер paywall UI и потока продуктов. Следуй [`REPORT_TEMPLATE.md`](REPORT_TEMPLATE.md), ничего не изменяй и не исправляй.

## Область

- `Sources/BroadMonetization/Data/Adapty/AdaptyPaywallRepository.swift`
- `Sources/BroadMonetization/Domain/Paywalls`
- `Sources/BroadMonetization/Application/Paywalls`
- `Sources/BroadUIFlows/Presentation/Paywall`
- paywall wiring в `Examples/BroadAppTemplate`
- `Documentation/PaywallUI.md`
- `Documentation/PlatformHandoff.md`

## Неизменные правила

- В UI попадают все продукты из ответа Adapty: любой count, исходный порядок и дубли сохраняются.
- SKU, тип периода, price, currency и product count никогда не используются для фильтрации, сортировки или обрезания каталога.
- Нажатие на product и CTA не меняе opacity, scale, brightness, tint или затемнение и не вызывает мерцание.

## Проверь

- Mapping между SDK products и domain products один-к-одному; каждая карточка имеет уникальный presentation/reference ID, даже если vendor ID дублируется.
- Наборы из 0, 1, 2 и N продуктов дают достижимый loader/empty/error/content без index-out-of-range.
- Длинный список прокручивается; CTA, restore, close и legal links доступны на маленьком и большом iPhone. iPad/Mac не входят в scope.
- Price и period отображаются из domain payload/formatter; нет hardcoded цен и привязки layout к weekly/monthly/yearly.
- Occurrence без валидного `Money` остаётся видимым 1:1 с unavailable price, но
  disabled, не выбирается по tap/default и не включает CTA.
- Если все occurrences неeligible, hard policy не скрывает close даже на время
  configured delay.
- Product row и CTA используют `BroadNoPressEffectButtonStyle`; нет `isPressed`-веток и implicit press animation.
- Повторный tap во время purchase блокируется логически, но весь paywall не темнеет; progress показан явно.
- Недоступные CTA, restore и expired product rows имеют semantic `.disabled`, чтобы VoiceOver не объявлял их активными; no-press style при этом не меняет визуал.
- Конфиг close delay не может навсегда запереть экран; при уходе View task отменяется.
- Selection не теряется и не перепрыгивает на другой product из-за одинакового SKU.
- Accessibility label карточки объединяет title, price и period, а selected state передаётся как trait/value.

Запусти `bash Scripts/check_architecture.sh`. `PASS` требует source guards и
локальные 0/1/2/N, duplicate и ineligible fixtures. Physical-device VoiceOver,
StoreKit sheet и два real apps исключены из platform handoff и не являются
причиной для `BLOCKED`.
