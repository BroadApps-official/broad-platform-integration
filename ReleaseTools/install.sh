#!/usr/bin/env bash
set -euo pipefail

usage='Использование: bash ReleaseTools/install.sh /path/to/App App.xcodeproj|App.xcworkspace AppScheme [--project PATH] [--workspace PATH] [--podfile PATH]'
if [[ $# -lt 3 ]]; then
    echo "$usage" >&2
    exit 2
fi

tool_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_root="$(cd "$1" && pwd)"
container="$2"
scheme="$3"
shift 3
project=''
workspace=''
podfile=''
case "$container" in
    *.xcodeproj) project="$container" ;;
    *.xcworkspace) workspace="$container" ;;
    *) echo "$usage" >&2; exit 2 ;;
esac
while [[ $# -gt 0 ]]; do
    if [[ $# -lt 2 ]]; then
        echo "$usage" >&2
        exit 2
    fi
    case "$1" in
        --project) project="$2" ;;
        --workspace) workspace="$2" ;;
        --podfile) podfile="$2" ;;
        *) echo "Неизвестный параметр: $1" >&2; exit 2 ;;
    esac
    shift 2
done

if [[ -n "$project" && ! -f "$app_root/$project/project.pbxproj" ]]; then
    echo "Не найден Xcode-проект: $app_root/$project" >&2
    exit 1
fi
if [[ -n "$workspace" && ! -f "$app_root/$workspace/contents.xcworkspacedata" && -z "$project" ]]; then
    echo "Workspace ещё не создан. Передайте .xcodeproj и --workspace для CocoaPods." >&2
    exit 1
fi
if [[ -z "$podfile" ]]; then
    if [[ -n "$workspace" && -f "$app_root/$(dirname "$workspace")/Podfile" ]]; then
        podfile="$(dirname "$workspace")/Podfile"
    elif [[ -n "$project" && -f "$app_root/$(dirname "$project")/Podfile" ]]; then
        podfile="$(dirname "$project")/Podfile"
    fi
fi
if [[ -n "$podfile" && ! -f "$app_root/$podfile" ]]; then
    echo "Не найден Podfile: $app_root/$podfile" >&2
    exit 1
fi
if [[ -n "$workspace" && ! -f "$app_root/$workspace/contents.xcworkspacedata" && -z "$podfile" ]]; then
    echo "Не найден workspace: $app_root/$workspace. Для генерации CocoaPods нужен Podfile." >&2
    exit 1
fi
workspace_projects=''
if [[ -n "$workspace" && -f "$app_root/$workspace/contents.xcworkspacedata" ]]; then
    if ! workspace_projects="$(ruby -r "$tool_root/prepare_release.rb" -e '
      begin
        puts ReleaseExport::Runner.allocate.send(:workspace_projects, ARGV[0], ARGV[1])
      rescue StandardError => error
        warn "Не удалось прочитать workspace: #{error.message}"
        exit 1
      end
    ' "$app_root" "$workspace")"; then
        exit 1
    fi
    if [[ -n "$project" ]] && ! printf '%s\n' "$workspace_projects" | grep -Fxq -- "$project"; then
        echo "Проект $project не входит в workspace $workspace." >&2
        exit 1
    fi
fi
shared=false
if [[ -n "$project" && -f "$app_root/$project/xcshareddata/xcschemes/$scheme.xcscheme" ]]; then
    shared=true
fi
if [[ -n "$workspace" && -f "$app_root/$workspace/xcshareddata/xcschemes/$scheme.xcscheme" ]]; then
    shared=true
fi
if [[ -n "$workspace_projects" ]]; then
    while IFS= read -r member; do
        if [[ -f "$app_root/$member/xcshareddata/xcschemes/$scheme.xcscheme" ]]; then
            shared=true
        fi
    done <<< "$workspace_projects"
fi
if [[ "$shared" != true ]]; then
    echo "Не найдена shared-схема $scheme. В Xcode откройте Product → Scheme → Manage Schemes, включите Shared и сохраните .xcscheme в Git." >&2
    exit 1
fi
if [[ -e "$app_root/Scripts/prepare_release.rb" || -e "$app_root/Scripts/prepare_release.sh" || -e "$app_root/Scripts/check_release_artifact.rb" || -e "$app_root/Scripts/check_release_source.rb" ]]; then
    echo "В приложении уже есть релизный инструмент. Обновите его после сравнения изменений." >&2
    exit 1
fi

mkdir -p "$app_root/Scripts"
cp "$tool_root/prepare_release.rb" "$app_root/Scripts/prepare_release.rb"
cp "$tool_root/check_release_artifact.rb" "$app_root/Scripts/check_release_artifact.rb"
cp "$tool_root/check_release_source.rb" "$app_root/Scripts/check_release_source.rb"
if [[ ! -e "$app_root/Scripts/codemagic.release.yaml" ]]; then
    cp "$tool_root/codemagic.release.template.yaml" "$app_root/Scripts/codemagic.release.yaml"
fi

args=(--scheme "$scheme")
[[ -z "$project" ]] || args+=(--project "$project")
[[ -z "$workspace" ]] || args+=(--workspace "$workspace")
[[ -z "$podfile" ]] || args+=(--podfile "$podfile")
cat > "$app_root/Scripts/prepare_release.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

app_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec ruby "$app_root/Scripts/prepare_release.rb" \
EOF
printf '  ' >> "$app_root/Scripts/prepare_release.sh"
printf '%q ' "${args[@]}" >> "$app_root/Scripts/prepare_release.sh"
printf '"$@"\n' >> "$app_root/Scripts/prepare_release.sh"
chmod +x "$app_root/Scripts/prepare_release.sh"

touch "$app_root/.gitignore"
for ignored in ReleaseExport/ ReleaseBranches/ ReleaseRecords/; do
    if ! grep -Fxq "$ignored" "$app_root/.gitignore"; then
        printf '\n%s\n' "$ignored" >> "$app_root/.gitignore"
    fi
done

echo "Инструмент установлен в $app_root/Scripts."
echo "Настройте Scripts/codemagic.release.yaml: пути, схему, подпись и публикацию."
echo "Проверьте diff и создайте коммит."
