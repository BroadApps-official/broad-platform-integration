# AgentKit — правила и скиллы BroadApps для агента

Набор для Claude Code и Codex: агент разработчика сразу работает по правилам компании.

| Что | Куда ставится |
|---|---|
| `rules.md` — правила разработки iOS-приложений BroadApps | Claude: `~/.claude/CLAUDE.md`, Codex: `~/.codex/AGENTS.md` (блок между маркерами) |
| `skills/broadapps-new-app` — старт и этапы приложения, временные данные аккаунта | `~/.claude/skills/`, `~/.codex/skills/` |
| `skills/broadapps-figma` — Figma в браузере без MCP, экспорт 6x | то же |
| `skills/broadapps-ipad-check` — проверка на iPad и iPhone SE | то же |

## Как ставит агент

Агент читает https://broadapps-ios-docs.nkhsnv.chatgpt.site/llms.txt, показывает
разработчику список и спрашивает «ставим?». После «да»:

```bash
git clone --depth 1 https://github.com/BroadApps-official/broad-platform-integration.git /tmp/broadapps-platform
bash /tmp/broadapps-platform/AgentKit/install.sh --list
bash /tmp/broadapps-platform/AgentKit/install.sh claude   # или codex / both
```

Повторный запуск обновляет правила на месте, свой текст разработчика вокруг блока не
трогается, прежний файл сохраняется как `*.bak-<время>`. Удалить — стереть блок между
`<!-- BroadApps iOS rules: begin -->` и `<!-- BroadApps iOS rules: end -->` и папки
`broadapps-*` в `skills`.
