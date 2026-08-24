#!/usr/bin/env bash

set -euo pipefail

platform_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Mutable runtime reports and the STATUS dashboard are intentionally excluded
# from the source snapshot. The automation prompt and executable scripts remain
# included, so any change to the actual review-and-fix procedure changes the
# digest.
# Generated Xcode project files and build products are excluded as well;
# project.yml and source inputs are part of the snapshot.
/usr/bin/ruby -rdigest -e '
  root = File.expand_path(ARGV.fetch(0))
  patterns = [
    ".swiftformat",
    ".swiftlint.yml",
    "AGENTS.md",
    "CHANGELOG.md",
    "Package.swift",
    "Package.resolved",
    "README.md",
    ".github/**/*",
    "Sources/**/*",
    "Examples/BroadAppTemplate/BroadAppTemplate/**/*",
    "Examples/BroadAppTemplate/Configuration/Adapty5013.xcconfig",
    "Examples/BroadAppTemplate/Configuration/Adapty5109Codex.xcconfig",
    "Examples/BroadAppTemplate/Configuration/LiveAdaptyInfo.plist",
    "Examples/BroadAppTemplate/README.md",
    "Examples/BroadAppTemplate/project.yml",
    "Examples/BroadAppTemplate/BroadAppTemplate.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved",
    "Documentation/**/*",
    "Scripts/**/*",
    "AgentChecks/*.md"
  ]

  excluded_relative_paths = ["AgentChecks/STATUS.md"]

  files = patterns
    .flat_map { |pattern| Dir.glob(File.join(root, pattern), File::FNM_DOTMATCH) }
    .select { |path| File.file?(path) }
    .reject { |path| excluded_relative_paths.include?(path.delete_prefix("#{root}/")) }
    .uniq
    .sort

  abort "Source snapshot contains no files" if files.empty?

  snapshot = Digest::SHA256.new
  files.each do |path|
    relative_path = path.delete_prefix("#{root}/")
    snapshot.update(relative_path)
    snapshot.update("\0")
    snapshot.update(Digest::SHA256.file(path).digest)
  end

  puts snapshot.hexdigest
' "$platform_root"
