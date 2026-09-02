#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "yaml"

root = File.expand_path("..", __dir__)
catalog_path = File.join(root, "Compatibility/current.yml")
project_path = File.join(root, "Examples/BroadAppTemplate/project.yml")
pbxproj_path = File.join(
  root,
  "Examples/BroadAppTemplate/BroadAppTemplate.xcodeproj/project.pbxproj"
)
resolved_paths = [
  File.join(root, "Package.resolved"),
  File.join(
    root,
    "Examples/BroadAppTemplate/BroadAppTemplate.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
  )
]

modules = {
  "BroadCore" => "broad-core-ios",
  "BroadExtensions" => "broad-extensions-ios",
  "BroadMonetization" => "broad-monetization-ios",
  "BroadUIFlows" => "broad-ui-flows-ios"
}.freeze

failures = []
record = ->(message) { failures << message }
semver = /\A\d+\.\d+\.\d+\z/
date = /\A\d{4}-\d{2}-\d{2}\z/

catalog = YAML.safe_load(File.read(catalog_path))
record.call("schema must equal 1") unless catalog["schema"] == 1
record.call("platform_set must be SemVer") unless catalog["platform_set"].to_s.match?(semver)
record.call("ios must equal 17.0") unless catalog["ios"].to_s == "17.0"
record.call("swift_language_mode must equal 5") unless catalog["swift_language_mode"].to_s == "5"
record.call("swift_tools must equal 6.0") unless catalog["swift_tools"].to_s == "6.0"

verification = catalog.fetch("verification", {})
record.call("verification.status must be passed") unless verification["status"] == "passed"
record.call("verification.command is invalid") unless verification["command"] == "bash Scripts/agent_gate.sh"
record.call("verification.checked_at is invalid") unless verification["checked_at"].to_s.match?(date)

platform_set = catalog["platform_set"].to_s
changelog_version = nil
File.foreach(File.join(root, "CHANGELOG.md")) do |line|
  changelog_version = line[/\A## (\d+\.\d+\.\d+)(?:\s|$)/, 1]
  break if changelog_version
end
record.call("CHANGELOG release does not match platform_set") unless changelog_version == platform_set

readme = File.read(File.join(root, "README.md"))
integration_release = "broad-platform-integration/releases/tag/#{platform_set}"
record.call("README integration release does not match platform_set") unless readme.include?(integration_release)

catalog_modules = catalog.fetch("modules", {})
repositories = catalog.fetch("repositories", {})
module_verification = catalog.fetch("module_verification", {})
versions = {}

modules.each do |name, identity|
  version = catalog_modules[name].to_s
  versions[identity] = version
  expected_repository = "https://github.com/BroadApps-official/#{identity}"
  expected_release = "#{expected_repository}/releases/tag/#{version}"

  record.call("#{name} version must be SemVer") unless version.match?(semver)
  record.call("#{name} repository is invalid") unless repositories[name] == expected_repository

  evidence = module_verification.fetch(name, {})
  record.call("#{name} evidence version does not match modules") unless evidence["version"].to_s == version
  %w[module_gate github_actions integration_gate].each do |field|
    record.call("#{name} #{field} must be passed") unless evidence[field] == "passed"
  end
  record.call("#{name} release URL is invalid") unless evidence["release"] == expected_release
  record.call("#{name} checked_at is invalid") unless evidence["checked_at"].to_s.match?(date)
end

package_swift = File.read(File.join(root, "Package.swift"))
manifest_versions = package_swift.scan(
  %r{url:\s*"https://github\.com/BroadApps-official/(broad-(?:core|extensions|monetization|ui-flows)-ios)\.git",\s*exact:\s*"([^"]+)"}m
).to_h
modules.each_value do |identity|
  record.call("Package.swift #{identity} pin is invalid") unless manifest_versions[identity] == versions[identity]
end

project = YAML.safe_load(File.read(project_path))
project_packages = project.fetch("packages", {})
target_dependencies = project.dig("targets", "BroadAppTemplate", "dependencies") || []
modules.each do |name, identity|
  package = project_packages.fetch(name, {})
  expected_url = "https://github.com/BroadApps-official/#{identity}.git"
  record.call("project.yml #{name} URL is invalid") unless package["url"] == expected_url
  record.call("project.yml #{name} exactVersion is invalid") unless package["exactVersion"].to_s == versions[identity]
  expected_dependency = { "package" => name, "product" => name }
  record.call("project.yml target does not link #{name}") unless target_dependencies.include?(expected_dependency)
end

pbxproj = File.read(pbxproj_path)
pbxproj_versions = pbxproj.scan(
  %r{repositoryURL = "https://github\.com/BroadApps-official/(broad-(?:core|extensions|monetization|ui-flows)-ios)\.git";\s*requirement = \{\s*kind = exactVersion;\s*version = ([^;]+);}m
).to_h
modules.each_value do |identity|
  record.call("project.pbxproj #{identity} pin is invalid") unless pbxproj_versions[identity] == versions[identity]
end

resolved_paths.each do |path|
  pins = JSON.parse(File.read(path)).fetch("pins")
  resolved_versions = pins.to_h do |pin|
    [pin.fetch("identity"), pin.dig("state", "version").to_s]
  end
  modules.each_value do |identity|
    record.call("#{path.delete_prefix("#{root}/")} #{identity} pin is invalid") unless resolved_versions[identity] == versions[identity]
  end
end

unless failures.empty?
  failures.each { |failure| warn failure }
  warn "Compatibility version matrix failed: #{failures.length} issue(s)."
  exit 1
end

summary = modules.map { |name, identity| "#{name} #{versions.fetch(identity)}" }.join(", ")
puts "Compatibility version matrix is consistent: #{summary}."
