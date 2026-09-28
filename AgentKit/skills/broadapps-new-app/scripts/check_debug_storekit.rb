#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks the local StoreKit configuration used for Debug purchases of a BroadApps app.
#
#   ruby check_debug_storekit.rb <app-dir> [--expect id1,id2,...]
#
# - every shared scheme that sets a StoreKit configuration points to an existing
#   file that is part of the Xcode project (otherwise Xcode shows it in red and
#   Debug purchases load no products);
# - the file is not copied into the app bundle;
# - with --expect, every product ID of the Adapty paywalls is in the file. The
#   IDs come from the account manager, the reference app or the platform DEBUG
#   warning "missing vendor product IDs".
#
# Prints the products with their prices so they can be compared with App Store.
# Exit status 1 when a check fails.

require 'json'
require 'optparse'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

expected = []
OptionParser.new do |options|
  options.banner = 'Usage: check_debug_storekit.rb <app-dir> [--expect id1,id2,...]'
  options.on('--expect IDS', 'Comma-separated product IDs the paywalls use') do |ids|
    expected = ids.split(',').map(&:strip).reject(&:empty?)
  end
end.parse!

app_dir = File.expand_path(ARGV.first || '.')
failures = []
warnings = []

projects = Dir.glob(File.join(app_dir, '*.xcodeproj'))
abort "FAIL: no .xcodeproj in #{app_dir}" if projects.empty?

storekit_files = []
projects.each do |project|
  pbxproj = File.read(File.join(project, 'project.pbxproj'))
  schemes = Dir.glob(File.join(project, 'xcshareddata', 'xcschemes', '*.xcscheme'))
  warnings << "#{File.basename(project)}: no shared schemes" if schemes.empty?

  schemes.each do |scheme|
    name = File.basename(scheme, '.xcscheme')
    reference = File.read(scheme)[/StoreKitConfigurationFileReference\s+identifier\s*=\s*"([^"]+)"/, 1]
    if reference.nil?
      warnings << "scheme #{name}: no StoreKit configuration (Debug purchases will not load products)"
      next
    end

    # Xcode resolves the identifier from the scheme's xcshareddata folder.
    path = File.expand_path(reference, File.join(project, 'xcshareddata'))
    file_name = File.basename(path)
    unless File.exist?(path)
      failures << "scheme #{name}: #{reference} does not exist"
      next
    end
    unless pbxproj.include?("/* #{file_name} */ = {isa = PBXFileReference")
      failures << "scheme #{name}: #{file_name} is not in the Xcode project (red in the scheme editor); " \
                  'add it to the project without a build phase'
    end
    if pbxproj.include?("/* #{file_name} in Resources */")
      warnings << "#{file_name} is copied into the app bundle; keep it out of Copy Bundle Resources"
    end
    storekit_files << path
  end
end

products = {}
storekit_files.uniq.each do |path|
  data = JSON.parse(File.read(path))
  Array(data['subscriptionGroups']).each do |group|
    Array(group['subscriptions']).each do |item|
      products[item['productID']] = [item['recurringSubscriptionPeriod'], item['displayPrice']]
    end
  end
  Array(data['nonRenewingSubscriptions']).each do |item|
    products[item['productID']] = ['non-renewing', item['displayPrice']]
  end
  Array(data['products']).each do |item|
    products[item['productID']] = [item['type'], item['displayPrice']]
  end
  puts "#{path.delete_prefix("#{app_dir}/")}: #{products.size} products"
rescue JSON::ParserError => error
  failures << "#{path}: invalid JSON (#{error.message.lines.first.strip})"
end

products.sort.each do |id, (kind, price)|
  puts format('  %-40<id>s %-14<kind>s %<price>s', id: id, kind: kind, price: price)
end

missing = expected - products.keys
unless missing.empty?
  failures << "missing in .storekit (add them with App Store prices): #{missing.join(', ')}"
end

warnings.each { |message| puts "WARN: #{message}" }
failures.each { |message| puts "FAIL: #{message}" }
if failures.empty?
  puts 'PASS: Debug StoreKit configuration'
else
  exit 1
end
