#!/usr/bin/env ruby
# frozen_string_literal: true

require "find"
require "pathname"

root = File.expand_path(ARGV.fetch(0, File.expand_path("..", __dir__)))
needles = ["github.com/" + "broadapps-official", "git@github.com:" + "broadapps-official"].map(&:b)
failures = []

Find.find(root) do |path|
  relative = Pathname.new(path).relative_path_from(Pathname.new(root)).to_s
  if File.basename(path) == ".git"
    failures << "вложенный .git: #{relative}" unless relative == ".git"
    Find.prune
  end
  if File.directory?(path)
    if relative == "ReleaseRecords"
      failures << "в релизной ветке есть внутренний отчёт: #{relative}"
      Find.prune
    elsif relative == "build"
      Find.prune
    end
    next
  end
  next unless File.file?(path)

  File.open(path, "rb") do |file|
    remainder = "".b
    while (chunk = file.read(1024 * 1024))
      content = (remainder + chunk).downcase
      if needles.any? { |needle| content.include?(needle) }
        failures << "ссылка на Git BroadApps: #{relative}"
        break
      end
      remainder = content.byteslice(-64, 64) || "".b
    end
  end
end

abort "Проверка релизной ветки не пройдена:\n#{failures.uniq.join("\n")}" unless failures.empty?
puts "Релизная ветка проверена: ссылок на Git BroadApps нет."
