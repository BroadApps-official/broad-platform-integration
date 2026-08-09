#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failure_count=0

record_failure() {
    printf '%b\n' "$1"
    failure_count=$((failure_count + 1))
}

link_failures="$(
    /usr/bin/ruby -ruri -e '
      root = File.expand_path(ARGV.fetch(0))
      files = [
        File.join(root, "README.md"),
        File.join(root, "CHANGELOG.md"),
        *Dir.glob(File.join(root, "Documentation/**/*.md")),
        *Dir.glob(File.join(root, "AgentChecks/**/*.md")),
        *Dir.glob(File.join(root, "Examples/**/*.md"))
      ].select { |path| File.file?(path) }.uniq.sort

      failures = []
      files.each do |source|
        text = File.read(source, encoding: "UTF-8")
        targets = text.scan(/\[[^\]]*\]\((?:<([^>]+)>|([^\s\)]+))/)
          .map { |angle, plain| angle || plain }
        targets += text.scan(/(?:src|srcset|href)="([^"]+)"/).flatten

        targets.each do |raw_target|
          target = raw_target.split(/\s+/).first.to_s
          next if target.empty? || target.start_with?("#")
          next if target.match?(/\A(?:https?:|mailto:|tel:|data:)/i)

          path_part = target.split("#", 2).first
          next if path_part.empty?

          begin
            decoded = URI::DEFAULT_PARSER.unescape(path_part)
          rescue ArgumentError
            decoded = path_part
          end
          resolved = File.expand_path(decoded, File.dirname(source))
          unless resolved == root || resolved.start_with?(root + File::SEPARATOR)
            failures << "#{source.delete_prefix(root + "/")}: link escapes package: #{target}"
            next
          end
          unless File.exist?(resolved)
            failures << "#{source.delete_prefix(root + "/")}: missing target: #{target}"
          end
        end
      end

      puts failures.uniq.sort
      exit(failures.empty? ? 0 : 1)
    ' "$platform_root"
)" || {
    record_failure "Broken local documentation links:\n$link_failures"
}

if ! /usr/bin/xmllint --noout "$platform_root"/Documentation/Assets/README/*.svg; then
    record_failure "README SVG validation failed."
fi

swift_module_cache="$platform_root/.build/DocumentationModuleCache"
mkdir -p "$swift_module_cache"

if ! CLANG_MODULE_CACHE_PATH="$swift_module_cache" \
    SWIFT_MODULECACHE_PATH="$swift_module_cache" \
    /usr/bin/xcrun swift "$platform_root/Scripts/check_gif_frames.swift" "$platform_root/Documentation/Assets/README/full-flow.gif" "$platform_root/Documentation/Assets/README/adaptive-paywall.gif"; then
    record_failure "README GIF validation failed."
fi

for required_pattern in \
    '^## Текущая готовность$' \
    'Documentation/Traceability\.md' \
    'Documentation/Analytics\.md' \
    'Documentation/AgentAutomation\.md' \
    'Documentation/PlatformHandoff\.md' \
    'Documentation/Assets/README/Screenshots/onboarding-dark\.png' \
    'Documentation/Assets/README/Screenshots/paywall-light\.png' \
    'Documentation/Assets/README/Screenshots/payment-methods-light\.png' \
    'Documentation/Assets/README/Screenshots/main-dark\.png' \
    'Documentation/Assets/README/full-flow\.gif' \
    'Documentation/Assets/README/adaptive-paywall\.gif'; do
    if ! rg -q "$required_pattern" "$platform_root/README.md"; then
        record_failure "README requirement is missing: $required_pattern"
    fi
done

for screenshot_path in \
    "$platform_root/Documentation/Assets/README/Screenshots/onboarding-dark.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/paywall-light.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/paywall-one-light.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/paywall-two-dark.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/paywall-many-dark.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/payment-methods-light.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/paywall-empty-dark.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/paywall-error-dark.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/main-dark.png"
do
    if [[ ! -s "$screenshot_path" ]]; then
        record_failure "README screenshot is missing: ${screenshot_path#$platform_root/}"
        continue
    fi

    screenshot_width="$(/usr/bin/sips -g pixelWidth "$screenshot_path" 2>/dev/null | /usr/bin/awk '/pixelWidth:/ { print $2 }')"
    screenshot_height="$(/usr/bin/sips -g pixelHeight "$screenshot_path" 2>/dev/null | /usr/bin/awk '/pixelHeight:/ { print $2 }')"
    if [[ "$screenshot_width" != "603" || "$screenshot_height" != "1311" ]]; then
        record_failure "README screenshot must be 603x1311: ${screenshot_path#$platform_root/} (${screenshot_width:-unknown}x${screenshot_height:-unknown})"
    fi
done

for required_file in \
    "$platform_root/Documentation/AgentAutomation.md" \
    "$platform_root/Documentation/PlatformHandoff.md" \
    "$platform_root/Examples/BroadAppTemplate/Configuration/Adapty5013.xcconfig" \
    "$platform_root/Examples/BroadAppTemplate/Configuration/Adapty5109Codex.xcconfig" \
    "$platform_root/Examples/BroadAppTemplate/Configuration/LiveAdaptyInfo.plist"
do
    if [[ ! -f "$required_file" ]]; then
        record_failure "Platform handoff file is missing: ${required_file#$platform_root/}"
    fi
done

if ((failure_count > 0)); then
    echo "Documentation validation failed: $failure_count check group(s)."
    exit 1
fi

echo "Documentation links and README assets are valid."
