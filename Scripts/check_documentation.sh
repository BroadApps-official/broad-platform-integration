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

readme_line_count="$(/usr/bin/wc -l < "$platform_root/README.md" | /usr/bin/tr -d ' ')"
if ((readme_line_count < 400 || readme_line_count > 650)); then
    record_failure "README must stay a 400-650 line landing page (actual: $readme_line_count)."
fi

for required_pattern in \
    '^## С чего начать$' \
    '^## Что подключать$' \
    '^## Целевые public repositories$' \
    '^### Идея новой архитектуры$' \
    '^## Если приложение уже сделано на старой платформе$' \
    '^## 🤖 Вариант A: сделать приложение через Codex или Claude$' \
    '^## 🛠️ Вариант B: собрать приложение вручную$' \
    '^### 🎁 Special Offer — только второй paywall$' \
    '^## Документация: repository плюс сайт$' \
    '^## Release и compatibility$' \
    '^## ✅ Если вы изменили код платформы$' \
    '^### Без unit tests$' \
    '^## BroadAppTemplate$' \
    '^## Карта документации$' \
    '^## Словарь$' \
    '^## Перед завершением задачи$' \
    'Host app подключает \*\*любой нужный модуль\*\*' \
    '`BroadPlatform` или другого umbrella package нет' \
    'Swift 5 language mode' \
    'SwiftPM 6\.0 — это не одно и то же' \
    '^### Как открыть сайт локально$' \
    'pnpm install --frozen-lockfile' \
    'pnpm run dev' \
    'README не копирует подробные статьи сайта' \
    'flowchart LR' \
    'Documentation/MigrationGuide\.md' \
    'Documentation/LegacyAppMigrationAgent\.md' \
    'не линковать old/new packages с одинаковым Swift module' \
    'https://broadapps-ios-docs\.nkhsnv\.chatgpt\.site' \
    'Documentation/FederatedRepositories\.md' \
    'Documentation/ModuleReleasePolicy\.md' \
    'Compatibility/current\.yml' \
    'Documentation/AppCreationWorkflow\.md' \
    'Documentation/AgentPromptPack\.md' \
    'Documentation/Templates/AppIntegrationPlan\.md' \
    'PLAN REVIEW REQUIRED' \
    'SKELETON REVIEW REQUIRED' \
    'SLICE REVIEW REQUIRED' \
    'FUNCTIONAL REVIEW REQUIRED' \
    'VISUAL REVIEW REQUIRED' \
    'BroadExtensions' \
    'BroadCore' \
    'BroadMonetization' \
    'BroadUIFlows' \
    'provider-managed Adapty payload' \
    'persistent cache `BroadMonetization` не может' \
    'SDK cache, Dashboard fallback и platform cache не авторизуют RU methods' \
    'bash Scripts/agent_gate\.sh' \
    'Tests/' \
    'XCTest' \
    'Swift Testing' \
    'Documentation/Assets/README/platform-module-selection-light\.svg' \
    'Documentation/Assets/README/platform-module-selection-dark\.svg' \
    'Documentation/Assets/README/federated-repositories-light\.svg' \
    'Documentation/Assets/README/federated-repositories-dark\.svg' \
    'Documentation/Assets/README/documentation-pipeline-light\.svg' \
    'Documentation/Assets/README/documentation-pipeline-dark\.svg' \
    'Documentation/Assets/README/module-release-flow-light\.svg' \
    'Documentation/Assets/README/module-release-flow-dark\.svg' \
    'Documentation/Assets/README/cross-repo-change-light\.svg' \
    'Documentation/Assets/README/cross-repo-change-dark\.svg'; do
    if ! rg -q -- "$required_pattern" "$platform_root/README.md"; then
        record_failure "README requirement is missing: $required_pattern"
    fi
done

for documentation_contract in \
    'Documentation/ADR/0006-federated-public-repositories.md|Host app подключает \*\*любой нужный модуль\*\*' \
    'Documentation/FederatedRepositories.md|broad-platform-integration' \
    'Documentation/FederatedRepositories.md|broad-docs' \
    'Documentation/ModuleReleasePolicy.md|upToNextMajor' \
    'Documentation/ModuleReleasePolicy.md|swift_language_mode: "5"' \
    'Documentation/GettingStarted.md|platform sources и host example компилируются в Swift 5 language mode' \
    'Documentation/MigrationGuide.md|^# Ручная миграция старого приложения$' \
    'Documentation/MigrationGuide.md|Не подключать одновременно packages, экспортирующие одинаковый Swift module' \
    'Documentation/LegacyAppMigrationAgent.md|MIGRATION PREFLIGHT REVIEW REQUIRED' \
    'Documentation/LegacyAppMigrationAgent.md|MIGRATION PLAN REVIEW REQUIRED' \
    'Documentation/LegacyAppMigrationAgent.md|DEPENDENCY SWITCH REVIEW REQUIRED' \
    'Documentation/LegacyAppMigrationAgent.md|MIGRATION SLICE REVIEW REQUIRED' \
    'Documentation/LegacyAppMigrationAgent.md|LEGACY CLEANUP REVIEW REQUIRED' \
    'Documentation/LegacyAppMigrationAgent.md|READY FOR QA' \
    'Documentation/LegacyAppMigrationAgent.md|https://github.com/BroadApps-official/broad-platform-integration' \
    'Documentation/LegacyAppMigrationAgent.md|HOST REPOSITORY' \
    'Documentation/LegacyAppMigrationAgent.md|PLATFORM REPOSITORY' \
    'Documentation/LegacyAppMigrationAgent.md|APP MIGRATION · BLOCKED' \
    'Documentation/Templates/AppIntegrationPlan.md|Platform documentation commit' \
    'Documentation/Templates/AppIntegrationPlan.md|Compatibility `platform_set`' \
    'Documentation/AgentPreflight.md|Platform source: READY / BLOCKED' \
    'Documentation/PlatformHandoff.md|exact: "1\.0\.0"' \
    'Documentation/SpecialOffer.md|Gate не стоит перед `getPaywallProducts`' \
    'Documentation/SpecialOffer.md|\.providerCacheFallbackPossible.*да.*да' \
    'Documentation/SpecialOffer.md|raw `AdaptyPaywallProduct`' \
    'Documentation/SpecialOffer.md|ru_pay.*\.verifiedFreshRemote' \
    'Examples/BroadAppTemplate/README.md|-special-offer-platform-cache' \
    'README.dev.md|-special-offer-looping-timer' \
    'Documentation/RUBilling.md|Release \| Verified-fresh remote payload' \
    'Documentation/RUBilling.md|Adapty\.setFallback\(fileURL:' \
    'Documentation/RUBilling.md|\.forceEnabled' \
    'Documentation/RemoteConfig.md|Release -> verified-fresh remote payload -> ru_pay' \
    'Documentation/Templates/AppIntegrationPlan.md|Как доказывается freshness' \
    'Examples/BroadAppTemplate/README.md|BROADAPPS_ADAPTY_FALLBACK_FILE_NAME' \
    'Documentation/Logging.md|ru-billing\.availability\.evaluated' \
    'Documentation/AccountRecovery.md|GET /me/token-balance' \
    'Documentation/AccountRecovery.md|Клиент не передаёт список StoreKit transaction ID' \
    'Documentation/AccountRecovery.md|unique \(provider, environment, externalOperationID\)' \
    'Documentation/Usedesk.md|Backend — источник, Keychain — локальный cache' \
    'Documentation/Usedesk.md|pendingBackendSync' \
    'Documentation/Usedesk.md|deactivateToken' \
    'Documentation/Usedesk.md|isSaveTokensInUserDefaults: false' \
    'CHANGELOG.md|Ответы на замечания: token recovery и Usedesk' \
    'CHANGELOG.md|Не проще ли после входа просто получать токены по backend-аккаунту' \
    'CHANGELOG.md|Почему Usedesk token не хранить в Keychain как deviceId/userId'
do
    documentation_file="${documentation_contract%%|*}"
    documentation_pattern="${documentation_contract#*|}"
    if ! rg -q -- "$documentation_pattern" "$platform_root/$documentation_file"; then
        record_failure "Documentation contract is missing: $documentation_file -> $documentation_pattern"
    fi
done

if rg -q -- 'idempotent ledger по StoreKit transaction ID|app backend token ledger' \
    "$platform_root/Documentation/AccountRecovery.md"; then
    record_failure "Account recovery still describes purchase-ID storage as the recovery input."
fi

if rg -q -- 'try\?[[:space:]]+await[[:space:]]+tokenRepository' \
    "$platform_root/Documentation/Usedesk.md"; then
    record_failure "Usedesk example silently swallows token persistence failures."
fi

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
    "$platform_root/Documentation/AppCreationWorkflow.md" \
    "$platform_root/Documentation/AgentPromptPack.md" \
    "$platform_root/Documentation/Templates/AppIntegrationPlan.md" \
    "$platform_root/Documentation/Examples/NeutralAppIntegrationPlan.md" \
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

if rg -q -- 'Архив: прежний монолитный build prompt|АРХИВНЫЙ PROMPT|^### 4\. 📋 Скопируйте основной build prompt$|^Проверь созданное iPhone-приложение и исправь найденные проблемы\.$' "$platform_root/README.md"; then
    record_failure "README must not contain an obsolete combined app build or final-review prompt."
fi

for checkpoint in \
    'PLAN REVIEW REQUIRED' \
    'SKELETON REVIEW REQUIRED' \
    'SLICE REVIEW REQUIRED' \
    'FUNCTIONAL REVIEW REQUIRED' \
    'VISUAL REVIEW REQUIRED' \
    'READY FOR QA'
do
    if ! rg -q -- "$checkpoint" "$platform_root/Documentation/AppCreationWorkflow.md" "$platform_root/Documentation/AgentPromptPack.md"; then
        record_failure "Staged app workflow checkpoint is missing: $checkpoint"
    fi
done

if ! rg -q -- '\[BLOCKED\] History' "$platform_root/Documentation/Examples/NeutralAppIntegrationPlan.md"; then
    record_failure "Neutral Integration Plan example must demonstrate a feature-level blocker."
fi

workflow_svgs=(
    "$platform_root/Documentation/Assets/README/app-delivery-iterations-light.svg"
    "$platform_root/Documentation/Assets/README/app-delivery-iterations-dark.svg"
    "$platform_root/Documentation/Assets/README/developer-roadmap-light.svg"
    "$platform_root/Documentation/Assets/README/developer-roadmap-dark.svg"
    "$platform_root/Documentation/Assets/README/agent-click-path-light.svg"
    "$platform_root/Documentation/Assets/README/agent-click-path-dark.svg"
    "$platform_root/Documentation/Assets/README/no-code-agent-workflow-light.svg"
    "$platform_root/Documentation/Assets/README/no-code-agent-workflow-dark.svg"
    "$platform_root/Documentation/Assets/README/no-code-manual-workflow-light.svg"
    "$platform_root/Documentation/Assets/README/no-code-manual-workflow-dark.svg"
)

federation_svgs=(
    "$platform_root/Documentation/Assets/README/platform-module-selection-light.svg"
    "$platform_root/Documentation/Assets/README/platform-module-selection-dark.svg"
    "$platform_root/Documentation/Assets/README/federated-repositories-light.svg"
    "$platform_root/Documentation/Assets/README/federated-repositories-dark.svg"
    "$platform_root/Documentation/Assets/README/repository-migration-light.svg"
    "$platform_root/Documentation/Assets/README/repository-migration-dark.svg"
    "$platform_root/Documentation/Assets/README/module-release-flow-light.svg"
    "$platform_root/Documentation/Assets/README/module-release-flow-dark.svg"
    "$platform_root/Documentation/Assets/README/cross-repo-change-light.svg"
    "$platform_root/Documentation/Assets/README/cross-repo-change-dark.svg"
    "$platform_root/Documentation/Assets/README/documentation-pipeline-light.svg"
    "$platform_root/Documentation/Assets/README/documentation-pipeline-dark.svg"
)

for federation_svg in "${federation_svgs[@]}"; do
    if [[ ! -s "$federation_svg" ]]; then
        record_failure "Federation README diagram is missing: ${federation_svg#$platform_root/}"
    fi
done

for federation_svg_contract in \
    'platform-module-selection|Host app выбирает любой нужный модуль' \
    'federated-repositories|Публичная федерация repositories' \
    'repository-migration|Порядок безопасной миграции' \
    'module-release-flow|Release одного модуля' \
    'cross-repo-change|Cross-repository change идёт снизу вверх' \
    'documentation-pipeline|Документы остаются рядом с кодом'
do
    federation_svg_name="${federation_svg_contract%%|*}"
    federation_svg_pattern="${federation_svg_contract#*|}"
    if ! rg -q -- "$federation_svg_pattern" \
        "$platform_root/Documentation/Assets/README/$federation_svg_name-light.svg" \
        "$platform_root/Documentation/Assets/README/$federation_svg_name-dark.svg"; then
        record_failure "Federation README diagram contract is missing: $federation_svg_name -> $federation_svg_pattern"
    fi
done

for remote_config_pattern in 'Dashboard fallback Adapty' 'Release: ru_pay только с verified freshness' 'Debug: follow / force-on / force-off'; do
    if ! rg -q -- "$remote_config_pattern" \
        "$platform_root/Documentation/Assets/README/remote-config-cache-flow-light.svg" \
        "$platform_root/Documentation/Assets/README/remote-config-cache-flow-dark.svg"; then
        record_failure "Remote Config README diagram is missing: $remote_config_pattern"
    fi
done

if rg -qi -- 'два промпта|второй промпт|готовый промпт|промпт проверки.*PASS' "${workflow_svgs[@]}"; then
    record_failure "Workflow SVGs must not describe the obsolete one-build-prompt/two-prompt process."
fi

for required_svg_pattern in 'INTEGRATION PLAN' 'ONE SLICE' 'CHECKPOINT' 'ACCEPTANCE'; do
    if ! rg -qi -- "$required_svg_pattern" "${workflow_svgs[@]}"; then
        record_failure "Workflow SVG contract is missing: $required_svg_pattern"
    fi
done

for required_main_flow_pattern in '0 · PREFLIGHT' '1 · PLAN' '2 · SKELETON' '3 · ONE SLICE' '4 · FUNCTIONAL' '5 · VISUAL' '6 · ACCEPTANCE' 'ВЕТКА BLOCKED'; do
    if ! rg -q -- "$required_main_flow_pattern" "$platform_root/Documentation/Assets/README/app-delivery-iterations-light.svg" "$platform_root/Documentation/Assets/README/app-delivery-iterations-dark.svg"; then
        record_failure "Seven-stage README diagram is missing: $required_main_flow_pattern"
    fi
done

for theme in light dark; do
    roadmap="$platform_root/Documentation/Assets/README/developer-roadmap-$theme.svg"
    click_path="$platform_root/Documentation/Assets/README/agent-click-path-$theme.svg"
    no_code_agent="$platform_root/Documentation/Assets/README/no-code-agent-workflow-$theme.svg"
    no_code_manual="$platform_root/Documentation/Assets/README/no-code-manual-workflow-$theme.svg"

    for pattern in 'Plan' 'skeleton' 'slice' 'acceptance'; do
        if ! rg -qi -- "$pattern" "$roadmap"; then
            record_failure "Developer roadmap ($theme) is missing staged marker: $pattern"
        fi
    done
    for pattern in 'PREFLIGHT' 'PLAN' 'SKELETON' 'SLICE' 'REVIEWS' 'ACCEPTANCE'; do
        if ! rg -q -- "$pattern" "$click_path"; then
            record_failure "Agent click path ($theme) is missing staged marker: $pattern"
        fi
    done
    for pattern in 'Plan' 'skeleton' 'vertical slice' 'CHECKPOINTS' 'acceptance'; do
        if ! rg -qi -- "$pattern" "$no_code_agent"; then
            record_failure "No-code agent workflow ($theme) is missing staged marker: $pattern"
        fi
    done
    for pattern in 'INTEGRATION PLAN' 'SKELETON' 'ONE SLICE' 'REVIEWS' 'ACCEPTANCE'; do
        if ! rg -q -- "$pattern" "$no_code_manual"; then
            record_failure "No-code manual workflow ($theme) is missing staged marker: $pattern"
        fi
    done
done

if ((failure_count > 0)); then
    echo "Documentation validation failed: $failure_count check group(s)."
    exit 1
fi

echo "Documentation links and README assets are valid."
