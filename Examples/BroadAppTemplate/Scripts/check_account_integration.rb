#!/usr/bin/ruby
# frozen_string_literal: true

# Build-time declarations, not a runtime switch or proof of backend behaviour.
# Kept inside the example so copying the template preserves the warning phase.
require 'json'

path = File.expand_path(ARGV.fetch(0) { '../Configuration/AccountIntegration.json' }, __dir__)
source = ''
errors = []
warnings = []
modes = {
  'tokens' => %w[demo backend notUsed],
  'accountRecovery' => %w[unconfigured backend notUsed],
  'iCloudIdentity' => %w[undecided enabled disabled]
}.freeze

begin
  source = File.read(path, encoding: 'UTF-8')
  config = JSON.parse(source)
  unless config.is_a?(Hash) && config['schema'] == 1
    raise ArgumentError, 'Ожидается объект AccountIntegration со schema: 1.'
  end
  unknown_keys = config.keys - ['schema'] - modes.keys
  errors << ['schema', "Неизвестные поля: #{unknown_keys.join(', ')}."] unless unknown_keys.empty?

  modes.each do |key, allowed|
    value = config[key]
    unless value.is_a?(Hash) && allowed.include?(value['mode'])
      errors << [key, "Укажите #{key}.mode: #{allowed.join(' / ')}. Отсутствие функции обозначается явно."]
      next
    end
    unless (value.keys - %w[mode details]).empty?
      errors << [key, "В #{key} поддерживаются только mode и details."]
    end
    unless value['details'].is_a?(String) && !value['details'].strip.empty?
      errors << [key, "Заполните #{key}.details: причину отсутствия функции или ссылку на реализацию/решение в плане приложения. Без секретов."]
    end
  end

  if errors.empty?
    tokens = config['tokens']['mode']
    recovery = config['accountRecovery']['mode']
    icloud = config['iCloudIdentity']['mode']

    if tokens == 'backend' && recovery != 'backend'
      errors << ['accountRecovery', 'Серверный баланс требует восстановления того же серверного аккаунта: accountRecovery.mode = backend.']
    end
    if icloud == 'enabled' && recovery != 'backend'
      errors << ['iCloudIdentity', 'Для переноса ID через iCloud сначала подключите подтверждение серверного аккаунта: accountRecovery.mode = backend.']
    end
    if tokens == 'demo'
      warnings << ['tokens', '[BA_ACCOUNT_001] Баланс токенов демонстрационный. Перед выпуском подключите backend; если токенов и баланса в приложении нет, укажите tokens.mode = notUsed и причину в details.']
    end
    if recovery == 'unconfigured'
      warnings << ['accountRecovery', '[BA_ACCOUNT_002] Серверное восстановление аккаунта не настроено. Подключите его либо явно укажите accountRecovery.mode = notUsed, если серверного аккаунта и личных данных нет. Keychain ID не подтверждает вход.']
    end
    if icloud == 'undecided'
      warnings << ['iCloudIdentity', '[BA_ACCOUNT_003] Политика iCloud не выбрана; в шаблоне синхронизация выключена. Укажите disabled, если перенос ID не нужен, либо enabled после подключения подтверждённого восстановления. JSON не меняет Swift-настройку.']
    end
  end
rescue JSON::ParserError, SystemCallError, ArgumentError => error
  # Do not echo parser input: a malformed app-owned file may contain secrets.
  errors << ['schema', "Не удалось прочитать корректный AccountIntegration.json (#{error.class}). Восстановите файл и обязательные поля; удаление файла не отключает проверку."]
end

diagnostic = lambda do |severity, key, message|
  index = source.lines.find_index { |line| line.match?(/^\s*"#{Regexp.escape(key)}"\s*:/) }
  puts "#{path}:#{index ? index + 1 : 1}:1: #{severity}: #{message}"
end
errors.each { |key, message| diagnostic.call('error', key, message) }
warnings.each { |key, message| diagnostic.call('warning', key, message) }

unless errors.empty? && warnings.empty?
  puts 'note: Инструкция: https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/backend-account-data'
end
if errors.empty? && warnings.empty?
  puts 'note: AccountIntegration: решения явно записаны. Проверка декларации не проверяет работу сервера и не изменяет функции приложения.'
end
exit(errors.empty? ? 0 : 1)
