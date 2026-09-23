#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Использование: bash ReleaseTools/install.sh /path/to/App App.xcodeproj AppScheme" >&2
    exit 2
fi

tool_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_root="$(cd "$1" && pwd)"
project="$2"
scheme="$3"

if [[ ! -f "$app_root/$project/project.pbxproj" ]]; then
    echo "Не найден Xcode-проект: $app_root/$project" >&2
    exit 1
fi
if [[ -e "$app_root/Scripts/prepare_release.rb" || -e "$app_root/Scripts/prepare_release.sh" || -e "$app_root/Scripts/check_release_artifact.rb" ]]; then
    echo "В приложении уже есть релизный инструмент. Обновите его после сравнения изменений." >&2
    exit 1
fi

mkdir -p "$app_root/Scripts"
cp "$tool_root/prepare_release.rb" "$app_root/Scripts/prepare_release.rb"
cp "$tool_root/check_release_artifact.rb" "$app_root/Scripts/check_release_artifact.rb"

printf -v project_quoted '%q' "$project"
printf -v scheme_quoted '%q' "$scheme"
cat > "$app_root/Scripts/prepare_release.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail

app_root="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"
exec ruby "\$app_root/Scripts/prepare_release.rb" \\
  --project $project_quoted --scheme $scheme_quoted "\$@"
EOF
chmod +x "$app_root/Scripts/prepare_release.sh"

touch "$app_root/.gitignore"
for ignored in ReleaseExport/ ReleaseRecords/; do
    if ! grep -Fxq "$ignored" "$app_root/.gitignore"; then
        printf '\n%s\n' "$ignored" >> "$app_root/.gitignore"
    fi
done

echo "Инструмент установлен в $app_root/Scripts. Проверьте diff и создайте коммит."
