# Обезличенный пример Integration Plan

Это учебный пример, а не статус реального приложения. Он показывает, как агент
останавливает одну неподтверждённую функцию и продолжает независимую работу без
выдуманного backend.

## Входы

| Вход | Доказательство | Статус |
|---|---|---|
| Требования | Экспорт с upload, result и history | `READY` |
| Design | Frames onboarding/main/result/history | `READY` |
| Platform | BroadApps iOS Platform | `READY` |
| Upload backend | Версионированная schema `POST /transform` | `READY` |
| History backend | В требованиях есть, в backend docs ручки нет | `BLOCKED` |
| Monetization | Subscription only, once after onboarding | `READY` |

## Ownership

| Область | Ответственность |
|---|---|
| AppFlow, entitlement, subscription mechanics | Platform component; агент только подключает |
| Upload mapping и экран результата | Агент реализует по доказанной schema и frames |
| History contract | Backend owner должен предоставить решение |
| Точные тексты/assets и visual acceptance | App-owned, подтверждает разработчик |

## Срезы

| Порядок | Срез | Статус | Следующее действие |
|---:|---|---|---|
| 1 | Launch → onboarding → main | `READY TO BUILD` | Создать platform-based каркас после plan review |
| 2 | Upload → transform → result | `READY TO BUILD` | Реализовать после skeleton review |
| 3 | History list → detail | `BLOCKED` | Получить endpoint/response/auth/errors у backend owner |
| 4 | Subscription → entitlement refresh | `READY TO BUILD` | Использовать platform flow без копирования internals |

## Правильный результат агента

```text
PLAN REVIEW REQUIRED

[BLOCKED] History
Нет: method, endpoint, response и правило пагинации.
Доказательство: функция есть в требованиях и design, в backend schema отсутствует.
Владелец: backend owner / product.
Независимо можно продолжить: каркас, upload/result и subscription slices.
```

Неправильный результат — придумать `GET /history`, показать локальный массив и
отметить History как готовую production-функцию.
