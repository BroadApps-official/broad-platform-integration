# Формат отчёта

## Жёсткий режим

- Работать только в read-only режиме.
- Не менять код, документацию, project-файлы и скрипты.
- Не запускать formatter, fixer или команды с автоисправлением.
- Не добавлять Tests и не предлагать тесты как обязательный этап.
- Каждое замечание подтверждать точным файлом и строкой.
- Не считать теоретическую опасность finding, если в текущем коде нет достижимого сценария.
- Явно разделять доказательства: static/code review, сборка, fixture manual QA
  и разрешённый live Adapty catalog smoke. Один тип не выдавать за другой.
- В сохранённом отчёте указывать дату, команды и все невыполненные live/manual checks; не подставлять commit, если Git не используется.
- Перед review выполнить `bash Scripts/source_snapshot_digest.sh`. После любого изменения snapshot отчёт считается stale и запускается заново.
- Добавить canonical дату и ровно по одной строке для verdict, digest, времени,
  run ID и review scope:

```text
Дата: YYYY-MM-DD
Вердикт: `PASS`
Source snapshot SHA-256: `<64 lowercase hex characters>`
Reviewed at UTC: `YYYY-MM-DDTHH:MM:SSZ`
Acceptance run ID: `<lowercase UUID>`
Review scope: `PLATFORM_LOCAL`
```

- Handoff gate не принимает future evidence и reports старше семи дней.
- Canonical lines пишутся без leading/trailing spaces. `Дата` должна совпадать с
  UTC calendar date из `Reviewed at UTC`.
- Во всех семи reports `Review scope` равен `PLATFORM_LOCAL`. Bundle IDs,
  `.ipa`, host attestations, StoreKit sandbox и device accessibility matrix в
  отчёт не требуются.
- `BLOCKED` ставится только при дефекте platform-owned scope или упавшей
  обязательной локальной команде. Company-policy ограничения перечисляются как
  `OUT_OF_SCOPE` и сами по себе не блокируют `PASS`.

## Приоритеты

- `P0` — утечка данных, оплата без права доступа, краш основного flow или иная блокирующая release-проблема.
- `P1` — нарушение обязательного правила платформы или реально ломающийся пользовательский сценарий.
- `P2` — ограниченный edge case, ошибка надёжности или существенное расхождение с документацией.
- `P3` — неблокирующее замечание по ясности или сопровождению.

## Формат отчёта

1. `Дата: YYYY-MM-DD` и ровно один canonical `Вердикт`: `PASS`, `PASS WITH FINDINGS` или `BLOCKED`.
2. Exact source digest, reviewed-at UTC, acceptance run ID и review scope.
3. `## Команды`: только реально выполненные read-only команды.
4. `## Проверено`: краткий список путей, fixture/config environment без secrets и что именно подтверждено.
5. `## Findings`: проблемы по убыванию приоритета. Для каждой: сценарий, почему это ошибка, файл и строка.
6. `## Неподтверждённые риски`: что нельзя доказать статически; отдельно
   перечислить `OUT_OF_SCOPE` company-policy сценарии.
7. `## Итог`: одно предложение о готовности направления.

Если findings нет, написать: `Findings: нет`.
