# Preflight первого реального приложения: 5135 Seedance

Дата: 2026-08-23. Этот документ фиксирует только проверенные входы. Account,
signing и provider identifiers из Kaiten намеренно не копируются.

Kaiten: доступен — найдены карточки `5135 Seedance` и `5135 Seedance Разработка`, прочитан Project Storage.
Источник дизайна: недоступен — Figma-файл и группы экранов видны, но точный design context требует editor-access.
Reference: нужен ответ — поле `Ref` в Project Storage пусто, локальный репозиторий 5135/Seedance не найден.
Backend: есть расхождения — указан только HTTPS host с login-страницей, API-контрактов нет.
Можно начинать: НЕТ

[BLOCKED] ПМ должен заполнить ТЗ и reference; владелец Figma — дать
editor/dev-доступ к нужным frames; backend-разработчик — передать versioned API
contract; тимлид — подтвердить product decisions ниже.

## Проверенные входы

| Вход | Факт | Статус |
|---|---|---|
| Kaiten | Карточка и Project Storage доступны через read-only connector | READY |
| Метка `no-code` | На найденных карточках отсутствует | READY: проект с Figma |
| ТЗ | Поле `TS` пусто | BLOCKED · ПМ |
| Figma | Ссылка существует; видны группы `onboarding + paywall`, `settings`, `history`, photo/video effects и prompts, splash | BLOCKED · нужен точный frame context |
| Reference | Поле `Ref` пусто; локальный Git/repository не найден | BLOCKED · ПМ/тимлид |
| Backend | Host доступен по HTTPS, но открывает login и не является API-документацией | BLOCKED · backend-разработчик |
| Git приложения | Поле пусто; отдельного локального проекта 5135 нет | BLOCKED · разработчик/тимлид |
| Legal/support | Ссылки присутствуют в Project Storage, но их продуктовая применимость ещё не подтверждена | BLOCKED · ПМ |
| Monetization | В Kaiten есть subscription, token и offer product names; реальные каталоги не открывались | PARTIAL |
| Ожидаемый offer product | Разработчик сообщил `offer_week_4.99_nottrial`; payload Adapty не загружался | REPORTED / BLOCKED до безопасного app-owned load/show |
| Analytics | Назначение, события и destinations не описаны | BLOCKED · ПМ/analytics owner |

## Таблица продуктовых решений

`Утверждено` означает прямое требование Kaiten, а не догадку по дизайну.

| Решение | Проверенный факт | Статус / кто подтверждает |
|---|---|---|
| Нужен onboarding | Checklist требует onboarding один раз и paywall сразу после него | Утверждено |
| Число страниц | Точный frame context недоступен | BLOCKED · дизайнер/ПМ |
| Источник каждого экрана | Figma, но node/frame map не выдан | BLOCKED · дизайнер |
| Subscription / tokens | В Project Storage перечислены продукты обоих типов | Утверждено по типам; состав каталога сверяет ПМ |
| Special offer | Сообщён product ID `offer_week_4.99_nottrial`, но placement, remote gate, eligibility/cooldown и live payload не подтверждены | BLOCKED · ПМ/Adapty owner |
| RU Billing | Требование отсутствует | BLOCKED · ПМ должен ответить `нет` или дать контракт |
| Initial paywall policy | Checklist требует показ после onboarding; повторные cold launch не описаны | BLOCKED · ПМ/тимлид |
| Close paywall | Checklist требует появление close через 5 секунд | Утверждено; policy безопасности сверяет тимлид |
| Входы token paywall | Не описаны | BLOCKED · ПМ/дизайнер |
| Backend fulfillment tokens | Контракт отсутствует | BLOCKED · backend-разработчик |
| Recovery token balance | Контракт отсутствует | BLOCKED · backend-разработчик |
| Premium authority | Adapty указан, entitlement ID/primary authority не описаны | BLOCKED · ПМ/backend |
| Account-required функции | Родительская карточка ждёт account, app-account contract отсутствует | BLOCKED · account/backend owner |
| Offline-функции | Не описаны | BLOCKED · ПМ/backend |

До снятия всех `BLOCKED` таблица не является утверждённой и не разрешает
функциональную итерацию приложения.

## Backend-матрица

Функции перечислены только по видимым группам Figma и monetization-входам.
Названия не доказывают наличие API.

| Функция | Method | Endpoint | Request / обязательные поля | Response | Auth | Ошибки / retry | Offline | Код / UI состояния | Достаточно |
|---|---|---|---|---|---|---|---|---|---|
| Photo prompt generation | Не указан | Не указан | Не указаны | Не указана | Не указана | Не указаны | Не описан | prompt → loading/error/result | НЕТ |
| Video prompt generation | Не указан | Не указан | Не указаны | Не указана | Не указана | Не указаны | Не описан | prompt → loading/error/result | НЕТ |
| Photo effects | Не указан | Не указан | Не указаны | Не указана | Не указана | Не указаны | Не описан | effects → processing/result | НЕТ |
| Video effects | Не указан | Не указан | Не указаны | Не указана | Не указана | Не указаны | Не описан | effects → processing/result | НЕТ |
| History | Не указан | Не указан | Не указаны | Не указана | Не указана | Не указаны | Не описан | loading/empty/error/content | НЕТ |
| Token fulfillment | Не указан | Не указан | StoreKit evidence и idempotency key не подтверждены | Balance snapshot не подтверждён | Не указана | Retry/reconciliation не описаны | Не описан | pending/credited/error/retry | НЕТ |
| Token balance recovery | Не указан | Не указан | Account identity не подтверждена | Snapshot не подтверждён | Не указана | Не описаны | Не описан | loading/error/balance | НЕТ |
| Premium entitlement | Не указан | Не указан | Subject/receipt contract не указан | active/inactive/unresolved не описаны | Не указана | Timeout/fallback не описаны | Не описан | gate/retry/main/paywall | НЕТ |

Кнопка или fixture не заменяют отсутствующий контракт. Реализация этапов 6–8
для 5135 остаётся внешне заблокированной до заполнения этой матрицы.
