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
        File.join(root, "README.dev.md"),
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
    '^## Перед завершением задачи$' \
    '^## 🤖 Вариант A: сделать приложение через Codex или Claude$' \
    '^## 🛠️ Вариант B: собрать приложение вручную$' \
    'Один результат — два способа работы' \
    '^### Шаг 0\. 🆕 Создайте новый iPhone-проект$' \
    '^### Шаг 9\. 🔍 Проверьте, меняли ли вы саму платформу$' \
    '^## 📖 Словарь: что означают термины$' \
    'Documentation/Traceability\.md' \
    'Documentation/Analytics\.md' \
    'Documentation/AccountRecovery\.md' \
    'Documentation/NetworkInterruptions\.md' \
    'Documentation/AgentAutomation\.md' \
    'Scripts/stream_example_logs\.sh' \
    'Текущий ответ SDK Adapty: сеть или внутренний кеш Adapty' \
    'Сохранённая копия из собственного кеша `BroadMonetization`' \
    '-special-offer-enabled' \
    '-special-offer-disabled' \
    '-special-offer-platform-cache' \
    '-special-offer-main-fallback' \
    '-special-offer-timed' \
    '-ru-pay-provider-enabled' \
    '-ru-pay-platform-cache' \
    '^## 💳 RU Billing: последовательность экранов$' \
    '^## ✅ Если вы изменили код платформы$' \
    '^### 6\. ✅ Запустите обязательную проверку перед сдачей$' \
    'AgentChecks/AUTOMATION_PROMPT\.md' \
    'agent_review_and_fix\.sh --doctor' \
    '^### Вариант 2 — запустить проверяющего агента вручную$' \
    'bash Scripts/agent_gate\.sh' \
    '^## BroadAppTemplate: зачем запускать пример$' \
    'технический пример подключения' \
    'Documentation/Assets/README/Screenshots/onboarding-ru-v2\.png' \
    'Documentation/Assets/README/Screenshots/paywall-showcase-ru-v2\.png' \
    'Documentation/Assets/README/References/5115-paywall-dark\.png' \
    'Documentation/Assets/README/References/5115-payment-methods-dark\.png' \
    'Documentation/Assets/README/References/5115-receipt-email-dark\.png' \
    'Documentation/Assets/README/References/5115-consent-alert-dark\.png' \
    'Documentation/Assets/README/References/5115-payment-ready-dark\.png' \
    'Documentation/Assets/README/References/5115-cloudpayments-light\.png' \
    'Documentation/Assets/README/References/5115-hosted-checkout-light\.png' \
    'Documentation/Assets/README/Screenshots/main-ru-v2\.png' \
    'Documentation/Assets/README/developer-roadmap-light\.svg' \
    'Documentation/Assets/README/developer-roadmap-dark\.svg' \
    'Documentation/Assets/README/reference-workflow-light\.svg' \
    'Documentation/Assets/README/reference-workflow-dark\.svg' \
    'Documentation/Assets/README/project-inputs-light\.svg' \
    'Documentation/Assets/README/project-inputs-dark\.svg' \
    'Documentation/Assets/README/composition-root-light\.svg' \
    'Documentation/Assets/README/composition-root-dark\.svg' \
    'Documentation/Assets/README/no-code-agent-workflow-light\.svg' \
    'Documentation/Assets/README/no-code-agent-workflow-dark\.svg' \
    'Documentation/Assets/README/no-code-manual-workflow-light\.svg' \
    'Documentation/Assets/README/no-code-manual-workflow-dark\.svg' \
    'Documentation/Assets/README/agent-click-path-light\.svg' \
    'Documentation/Assets/README/agent-click-path-dark\.svg' \
    'Documentation/Assets/README/onboarding-decision-flow-light\.svg' \
    'Documentation/Assets/README/onboarding-decision-flow-dark\.svg' \
    'Documentation/Assets/README/remote-config-cache-flow-light\.svg' \
    'Documentation/Assets/README/remote-config-cache-flow-dark\.svg' \
    'Documentation/Assets/README/full-flow\.gif' \
    'Documentation/Assets/README/adaptive-paywall\.gif' \
    'Copy-paste: обязательная инструкция агенту перед onboarding' \
    'Три слайда в `BroadAppTemplate` — только демонстрационный пример' \
    'production-shape fixture' \
    'FUNCTIONAL REVIEW REQUIRED' \
    'маленьком и большом iPhone Simulator' \
    'offer_week_4\.99_nottrial' \
    'BroadOnboardingFlowHost' \
    '^### 🎁 Special Offer — всегда второй paywall$' \
    'presentation=special-offer' \
    'Documentation/Assets/README/References/special-offer-step-1-paywall\.png' \
    'Documentation/Assets/README/References/special-offer-step-2-offer\.png'; do
    if ! rg -q -- "$required_pattern" "$platform_root/README.md"; then
        record_failure "README requirement is missing: $required_pattern"
    fi
done

for reference_path in \
    "$platform_root/Documentation/Assets/README/References/5115-paywall-dark.png" \
    "$platform_root/Documentation/Assets/README/References/5115-payment-methods-dark.png" \
    "$platform_root/Documentation/Assets/README/References/5115-receipt-email-dark.png" \
    "$platform_root/Documentation/Assets/README/References/5115-consent-alert-dark.png" \
    "$platform_root/Documentation/Assets/README/References/5115-payment-ready-dark.png" \
    "$platform_root/Documentation/Assets/README/References/5115-cloudpayments-light.png" \
    "$platform_root/Documentation/Assets/README/References/5115-hosted-checkout-light.png"
do
    if [[ ! -s "$reference_path" ]]; then
        record_failure "README RU Billing flow screenshot is missing: ${reference_path#$platform_root/}"
        continue
    fi

    reference_width="$(/usr/bin/sips -g pixelWidth "$reference_path" 2>/dev/null | /usr/bin/awk '/pixelWidth:/ { print $2 }')"
    reference_height="$(/usr/bin/sips -g pixelHeight "$reference_path" 2>/dev/null | /usr/bin/awk '/pixelHeight:/ { print $2 }')"
    if [[ "$reference_width" != "645" || "$reference_height" != "1398" ]]; then
        record_failure "README RU Billing flow screenshot must be 645x1398: ${reference_path#$platform_root/} (${reference_width:-unknown}x${reference_height:-unknown})"
    fi
done

for screenshot_path in \
    "$platform_root/Documentation/Assets/README/Screenshots/ru-payment-methods-v3.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/ru-payment-apple-v2.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/ru-payment-receipt-v2.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/ru-subscription-active-v2.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/ru-subscription-cancelled-v2.png"
do
    if [[ ! -s "$screenshot_path" ]]; then
        record_failure "README screenshot is missing: ${screenshot_path#$platform_root/}"
        continue
    fi

    screenshot_width="$(/usr/bin/sips -g pixelWidth "$screenshot_path" 2>/dev/null | /usr/bin/awk '/pixelWidth:/ { print $2 }')"
    screenshot_height="$(/usr/bin/sips -g pixelHeight "$screenshot_path" 2>/dev/null | /usr/bin/awk '/pixelHeight:/ { print $2 }')"
    if [[ "$screenshot_width" != "1206" || "$screenshot_height" != "2622" ]]; then
        record_failure "README RU screenshot must be native 1206x2622: ${screenshot_path#$platform_root/} (${screenshot_width:-unknown}x${screenshot_height:-unknown})"
    fi
done

for screenshot_path in \
    "$platform_root/Documentation/Assets/README/Screenshots/onboarding-ru-v2.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/paywall-showcase-ru-v2.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/paywall-one-ru-v2.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/paywall-two-ru-v2.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/paywall-many-ru-v2.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/payment-methods-light.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/paywall-empty-ru-v2.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/paywall-error-ru-v2.png" \
    "$platform_root/Documentation/Assets/README/Screenshots/main-ru-v2.png"
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
    "$platform_root/Documentation/AccountRecovery.md" \
    "$platform_root/Documentation/AgentAutomation.md" \
    "$platform_root/Documentation/NetworkInterruptions.md" \
    "$platform_root/Documentation/PurchaseManagers.md" \
    "$platform_root/Documentation/PlatformHandoff.md" \
    "$platform_root/Documentation/SpecialOffer.md" \
    "$platform_root/Documentation/RemoteConfig.md" \
    "$platform_root/Documentation/ADR/0005-provider-managed-remote-feature-gates.md" \
    "$platform_root/Examples/BroadAppTemplate/Configuration/Adapty5013.xcconfig" \
    "$platform_root/Examples/BroadAppTemplate/Configuration/Adapty5109Codex.xcconfig" \
    "$platform_root/Examples/BroadAppTemplate/Configuration/LiveAdaptyInfo.plist"
do
    if [[ ! -f "$required_file" ]]; then
        record_failure "Required documentation or example configuration is missing: ${required_file#$platform_root/}"
    fi
done

if ((failure_count > 0)); then
    echo "Documentation validation failed: $failure_count check group(s)."
    exit 1
fi

echo "Documentation links and README assets are valid."
