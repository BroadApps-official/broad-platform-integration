#!/usr/bin/env bash
# Installs the BroadApps iOS development rules and skills into a coding agent.
#
#   bash AgentKit/install.sh --list            # show what would be installed
#   bash AgentKit/install.sh claude            # ~/.claude/CLAUDE.md + ~/.claude/skills
#   bash AgentKit/install.sh codex             # ~/.codex/AGENTS.md + ~/.codex/skills
#   bash AgentKit/install.sh both
#
# The rules live between marker lines, so running it again updates them in place
# instead of appending a copy. The previous file is kept as <file>.bak-<timestamp>.

set -euo pipefail

kit_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rules_file="$kit_root/rules.md"
skills_root="$kit_root/skills"
begin_marker="<!-- BroadApps iOS rules: begin -->"
end_marker="<!-- BroadApps iOS rules: end -->"

list_contents() {
    echo "Правила (rules.md):"
    grep '^## ' "$rules_file" | sed 's/^## /  - /'
    echo "Скиллы:"
    for skill in "$skills_root"/*/SKILL.md; do
        name="$(sed -n 's/^name: //p' "$skill" | head -1)"
        description="$(sed -n 's/^description: //p' "$skill" | head -1)"
        echo "  - $name — $description"
    done
}

install_rules() {
    local target="$1"
    mkdir -p "$(dirname "$target")"
    touch "$target"
    cp "$target" "$target.bak-$(date +%Y%m%d%H%M%S)"

    local block
    block="$(printf '%s\n' "$begin_marker"; cat "$rules_file"; printf '%s\n' "$end_marker")"

    if grep -qF "$begin_marker" "$target"; then
        # Replace the existing block, keep everything the user wrote around it.
        awk -v begin="$begin_marker" -v end="$end_marker" -v block_file=<(printf '%s\n' "$block") '
            BEGIN { while ((getline line < block_file) > 0) replacement = replacement line "\n" }
            $0 == begin { printf "%s", replacement; skipping = 1; next }
            $0 == end { skipping = 0; next }
            !skipping { print }
        ' "$target" > "$target.tmp"
        mv "$target.tmp" "$target"
        echo "Обновлены правила в $target"
    else
        { [ -s "$target" ] && printf '\n'; printf '%s\n' "$block"; } >> "$target"
        echo "Добавлены правила в $target"
    fi
}

install_skills() {
    local target_root="$1"
    mkdir -p "$target_root"
    for skill_dir in "$skills_root"/*/; do
        local name
        name="$(basename "$skill_dir")"
        rm -rf "${target_root:?}/$name"
        cp -R "$skill_dir" "$target_root/$name"
        echo "Скилл $name → $target_root/$name"
    done
}

case "${1:-}" in
    --list)
        list_contents
        ;;
    claude)
        install_rules "$HOME/.claude/CLAUDE.md"
        install_skills "$HOME/.claude/skills"
        ;;
    codex)
        install_rules "$HOME/.codex/AGENTS.md"
        install_skills "$HOME/.codex/skills"
        ;;
    both)
        install_rules "$HOME/.claude/CLAUDE.md"
        install_skills "$HOME/.claude/skills"
        install_rules "$HOME/.codex/AGENTS.md"
        install_skills "$HOME/.codex/skills"
        ;;
    *)
        echo "Usage: bash AgentKit/install.sh --list | claude | codex | both" >&2
        exit 1
        ;;
esac
