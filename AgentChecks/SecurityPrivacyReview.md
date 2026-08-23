# Security и privacy review

Дата: 2026-08-23. Scope — платформа, BroadAppTemplate и текущий diff. Review
конкретного host app выполняется отдельно по его network/configuration source.

## Результат

`PASS` для platform/template source contract. Реальные credentials, payment
operations и production payload не использовались.

| Требование | Доказательство | Статус |
|---|---|---|
| В логах нет email/token/receipt/JWS/payment URL | `BroadLogEvent` принимает bounded typed fields; raw logging APIs в app/source не найдены | PASS |
| Provider payload не печатается целиком | Analytics исключает payload/identity; legacy free-form event отбрасывается | PASS |
| Support log очищен | Template формирует bounded строки без ID/payload | PASS |
| Debug Keychain очищает только app-owned services | Точный class/service scope, весь инструмент под `#if DEBUG` | PASS |
| Payment pending не очищается Debug UI | Доступны только keychain/flow/cache/in-memory analytics scopes | PASS |
| Entitlement/token не берутся из content cache | Premium идёт через entitlement authority, balance — через fulfillment/recovery | PASS |
| Credentials отсутствуют в Git/current diff | Secret patterns и key/certificate/provisioning files не найдены | PASS |
| Privacy manifest соответствует API | `bash Scripts/check_privacy_manifest.sh` | PASS |
| Release без Debug-каталога | Debug composition ограждена `#if DEBUG` | PASS |

## Конфигурационная граница

Инструкции разрешают fixture или явно согласованные public client values для
load/show. Нельзя копировать live bundle, credentials, keys/certificates,
backend auth, API/user chat tokens и account/user data из reference. Signing
не требуется для обязательной Simulator-first проверки.

## Граница результата

Каждый host app повторяет review для своих analytics destinations, network
clients, support-log source, app-owned configuration и Release binary. Platform
`PASS` не доказывает этот будущий app-level результат.
