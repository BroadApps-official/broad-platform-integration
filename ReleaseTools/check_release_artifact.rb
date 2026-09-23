#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

ipa = ARGV.fetch(0) { abort "Укажите путь к готовому .ipa." }
abort "Файл .ipa не найден: #{ipa}" unless File.file?(ipa)
app_root = File.expand_path("..", __dir__)
needles = ["github.com/broadapps-official", "git@github.com:broadapps-official"].map(&:b)
failures = []
ipa_version = nil

scan_file = lambda do |path, label|
  File.open(path, "rb") do |file|
    remainder = "".b
    while (chunk = file.read(1024 * 1024))
      content = (remainder + chunk).downcase
      if needles.any? { |needle| content.include?(needle) }
        failures << "ссылка на Git BroadApps: #{label}"
        break
      end
      remainder = content.byteslice(-64, 64) || "".b
    end
  end
end

Dir.mktmpdir("release-ipa-") do |unpacked|
  abort "Не удалось открыть .ipa." unless system("unzip", "-q", ipa, "-d", unpacked)
  apps = Dir.glob(File.join(unpacked, "Payload", "*.app"))
  abort "В .ipa ожидалось одно приложение, найдено #{apps.length}." unless apps.length == 1
  info_plist = File.join(apps.first, "Info.plist")
  abort "В .ipa отсутствует Info.plist приложения." unless File.file?(info_plist)
  version, version_status = Open3.capture2e("/usr/libexec/PlistBuddy", "-c", "Print :CFBundleShortVersionString", info_plist)
  abort "Не удалось прочитать версию приложения из .ipa." unless version_status.success?
  ipa_version = version.strip
  Dir.glob(File.join(unpacked, "**", "*"), File::FNM_DOTMATCH).each do |path|
    relative = path.delete_prefix("#{unpacked}/")
    failures << "служебный файл: #{relative}" if %w[.git ReleaseRecords].include?(File.basename(path))
    next unless File.file?(path)
    scan_file.call(path, relative)
  end
end

ARGV.drop(1).each do |symbols_root|
  next unless File.directory?(symbols_root)
  Dir.glob(File.join(symbols_root, "**", "*.dSYM", "**", "*"), File::FNM_DOTMATCH).each do |path|
    scan_file.call(path, path) if File.file?(path)
  end
end
abort "Проверка релизных файлов не пройдена:\n#{failures.uniq.join("\n")}" unless failures.empty?

record_path = File.join(app_root, "ReleaseRecords", "#{ipa_version}.json")
abort "Внутренний отчёт для версии #{ipa_version} не найден." unless File.file?(record_path)
record = JSON.parse(File.read(record_path))
abort "Версия .ipa #{ipa_version} не совпадает с отчётом #{record['version']}." unless record["version"] == ipa_version
record["archive_sha256"] = Digest::SHA256.file(ipa).hexdigest
record["artifact_check"] = "passed"
record["build_check"] = "passed"
File.write(record_path, JSON.pretty_generate(record) + "\n")
puts "Проверка релизных файлов пройдена: ссылок на Git BroadApps и служебного отчёта нет."
