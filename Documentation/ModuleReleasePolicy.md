# Версии и release модулей

## Единица release

Единица release — один module repository, а не вся платформа. Каждый модуль
имеет собственные `CHANGELOG.md` и SemVer tags.

| Изменение | Version bump |
|---|---|
| Backward-compatible fix | patch |
| Backward-compatible public API | minor |
| Breaking public API или поведение | major |
| Только docs/CI без изменения package | patch при необходимости distribution |

## Dependency ranges

Module repositories используют `upToNextMajor`, начиная с минимальной
проверенной версии. `broad-platform-integration` использует exact versions,
чтобы воспроизводить acceptance.

```text
module package:      from: "1.2.0"
integration catalog: exact: "1.2.3"
```

Нижняя граница диапазона поднимается, если новый API необходим для сборки.

## Release checklist

1. Working tree чистый, public branch актуален.
2. Changelog объясняет **что** изменилось и **почему**.
3. Public API report сопоставлен с выбранным SemVer bump.
4. `module_gate.sh` и iPhone sandbox compile прошли.
5. Нет test targets/frameworks, secrets и app-owned identifiers.
6. DocC, README, links и assets прошли проверку.
7. Если менялся dependency contract, dependent module gates повторены.
8. Integration repository собран с candidate commit/tag.
9. Только затем создан подписанный tag и GitHub Release.
10. Compatibility catalog и docs-site обновлены теми же exact versions.

## Compatibility catalog

Canonical schema лежит в `Compatibility/current.yml` integration repository:

```yaml
schema: 1
platform_set: "1.0.0"
ios: "17.0"
swift_tools: "6.0"
modules:
  BroadCore: "1.0.0"
  BroadExtensions: "1.0.0"
  BroadMonetization: "1.0.0"
  BroadUIFlows: "1.0.0"
verification:
  status: passed
  command: "bash Scripts/agent_gate.sh"
```

`platform_set` — версия проверенного набора, а не обязательного runtime
umbrella. Host app может взять один модуль из этой матрицы.

## Emergency fix

Срочность не отменяет gate. Fix выпускается в module repository, после чего
интеграционная матрица перепроверяется. Если общая проверка ещё не
завершена, compatibility catalog не помечается `passed`.
