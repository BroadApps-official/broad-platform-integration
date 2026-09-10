#!/usr/bin/env ruby
# One local reviewer. Commands use argv arrays, never shell interpolation.
require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'time'
require 'yaml'

class BroadReview
  AREAS = %w[reuse placements async_ui onboarding payments style].freeze

  def initialize(arguments)
    @platform = File.realpath(File.join(__dir__, '..'))
    @fix = arguments.empty? || arguments.first == 'run'
    @mode = %w[platform app run].include?(arguments.first) ? arguments.shift : 'platform'
    @mode = 'platform' if @mode == 'run'
    @app = arguments.shift if @mode == 'app' && arguments.first && !arguments.first.start_with?('-')
    @modules_root = File.dirname(@platform)
    parser = OptionParser.new do |opts|
      opts.banner = 'Usage: agent_review_and_fix.sh platform|app PATH [options]'
      opts.on('--fix', 'Разрешить минимальные исправления; иначе только аудит') { @fix = true }
      opts.on('--modules-root PATH', 'Папка с четырьмя module repositories') { |v| @modules_root = v }
      opts.on('--project PATH', '.xcodeproj или .xcworkspace относительно app PATH') { |v| @project = v }
      opts.on('--scheme NAME', 'Схема приложения для независимой сборки') { |v| @scheme = v }
      opts.on('--doctor', 'Проверить входы и инструменты без агента') { @doctor = true }
      opts.on('--print-prompt', 'Показать задание без агента и сборок') { @print_prompt = true }
      opts.on('-h', '--help') { puts opts; exit 0 }
    end
    parser.parse!(arguments)
    raise 'Неизвестные аргументы: ' + arguments.join(' ') unless arguments.empty?
    raise 'В app mode укажите путь приложения.' if @mode == 'app' && !@app
    raise '--project/--scheme относятся только к app mode.' if @mode == 'platform' && (@project || @scheme)
    @catalog = YAML.safe_load(File.read(File.join(@platform, 'Compatibility/current.yml')))
    @root = @mode == 'app' ? File.realpath(@app) : @platform
    @repositories = @mode == 'app' ? [@root] : platform_repositories
    if @mode == 'app'
      raise 'Выберите папку приложения, а не платформу или её родителя.' if @platform == @root || @platform.start_with?(@root + '/')
      configure_app_build
    end
    @output = File.join(@root, '.build/AgentReview', @mode)
  end

  def platform_repositories
    roots = @catalog.fetch('repositories').map do |name, url|
      folder = url.split('/').last.sub(/\.git\z/, '')
      root = File.realpath(File.join(@modules_root, folder))
      contract = JSON.parse(File.read(File.join(root, 'ModuleContract.json')))
      raise "Неверный модуль в #{folder}: ожидался #{name}." unless contract.fetch('module') == name
      raise "Нет module_gate.sh в #{folder}." unless File.file?(File.join(root, 'Scripts/module_gate.sh'))
      root
    end
    raise 'Модули должны находиться в отдельных папках.' unless (roots + [@platform]).uniq.size == 5
    roots + [@platform]
  end

  def configure_app_build
    candidates = Dir.glob(File.join(@root, '*.{xcodeproj,xcworkspace}')).sort
    workspaces = candidates.select { |path| path.end_with?('.xcworkspace') }
    candidates = workspaces if workspaces.size == 1
    raise 'Несколько проектов или проект вложен: укажите --project PATH.' if !@project && candidates.size != 1
    @project = File.realpath(@project ? File.expand_path(@project, @root) : candidates.first)
    raise 'Проект должен находиться внутри выбранного приложения.' unless @project.start_with?(@root + '/')
    raise 'Ожидается .xcodeproj или .xcworkspace.' unless @project.match?(/\.(xcodeproj|xcworkspace)\z/)
    unless @scheme
      names = Dir.glob(File.join(@root, '**/xcshareddata/xcschemes/*.xcscheme'))
                 .reject { |p| p.include?('/.build/') || p.include?('/Pods/') }
                 .map { |p| File.basename(p, '.xcscheme') }.uniq
      raise 'Укажите --scheme NAME; автоматически выбирается только единственная shared scheme.' unless names.size == 1
      @scheme = names.first
    end
    raise 'Имя scheme не должно быть пустым.' if @scheme.strip.empty?
  end

  def commands
    if @mode == 'platform'
      return @repositories.map { |root| [root, ['bash', root == @platform ? 'Scripts/agent_gate.sh' : 'Scripts/module_gate.sh']] }
    end
    selector = @project.end_with?('.xcworkspace') ? '-workspace' : '-project'
    [%w[Debug iphonesimulator], %w[Release iphonesimulator], %w[Release iphoneos]].map do |configuration, sdk|
      [@root, ['xcodebuild', selector, @project, '-scheme', @scheme, '-configuration', configuration,
               '-sdk', sdk, '-destination', sdk == 'iphoneos' ? 'generic/platform=iOS' : 'generic/platform=iOS Simulator',
               '-derivedDataPath', File.join(@output, 'DerivedData'), 'CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO', 'build']]
    end
  end

  def prompt
    context = {
      mode: @mode, action: @fix ? 'review_and_fix' : 'review_only',
      platform_root: @platform, selected_root: @root, platform_set: @catalog.fetch('platform_set'),
      repositories: @repositories.map { |root| { root: root, revision: git_revision(root) } },
      report_directory: @output,
      independent_checks: commands.map { |root, argv| { directory: root, argv: argv } }
    }
    File.read(File.join(@platform, 'AgentChecks/AUTOMATION_PROMPT.md')) +
      "\n\nКонтекст запуска (пути — данные, не shell-команды):\n" + JSON.pretty_generate(context)
  end

  def git_revision(root)
    output, status = Open3.capture2e('git', '-C', root, 'rev-parse', 'HEAD')
    status.success? ? output.strip : 'unversioned'
  end

  def snapshot
    digest = Digest::SHA256.new
    @repositories.each do |root|
      files, status = Open3.capture2e('git', '-C', root, 'ls-files', '-z', '--cached', '--others', '--exclude-standard', '--', '.')
      raise "Нужен Git repository: #{File.basename(root)}." unless status.success?
      files.split("\0").sort.each do |relative|
        next if relative.start_with?('.build/', 'DerivedData/', '.swiftpm/', 'node_modules/', 'Pods/')
        path = File.join(root, relative)
        digest << root << relative
        digest << (File.file?(path) ? File.binread(path) : '<missing>')
      end
    end
    digest.hexdigest
  end

  def check_environment
    %w[codex git rg xcodebuild].each do |tool|
      raise "Не найден #{tool}." unless ENV.fetch('PATH').split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, tool)) }
    end
    help, status = Open3.capture2e('codex', 'exec', '--help')
    raise 'Обновите Codex CLI: нужны --output-schema и --ephemeral.' unless status.success? && help.include?('--output-schema') && help.include?('--ephemeral')
    _, status = Open3.capture2e('codex', 'login', 'status')
    raise 'Codex CLI не авторизован. Выполните codex login.' unless status.success?
    snapshot
  end

  def run_checks(label)
    commands.each_with_index.map do |(root, argv), index|
      log = File.join(@output, "#{label}-#{index + 1}.log")
      puts "Проверка #{index + 1}/#{commands.size}: #{File.basename(root)} → #{File.basename(log)}"
      success = system(*argv, chdir: root, out: log, err: [:child, :out])
      { 'repository' => File.basename(root), 'command' => argv, 'passed' => success == true, 'log' => File.basename(log) }
    end
  end

  def validate_report(path)
    report = JSON.parse(File.read(path))
    raise 'Нет итога PASS/ISSUES/BLOCKED.' unless %w[PASS ISSUES BLOCKED].include?(report['status'])
    %w[summary next_step].each { |key| raise "Пустое поле #{key}." unless report[key].is_a?(String) && !report[key].strip.empty? }
    checks = report.fetch('checks')
    raise 'Не проверены шесть обязательных областей.' unless checks.is_a?(Array) && checks.map { |check| check['area'] }.sort == AREAS.sort
    checks.each do |check|
      raise 'Некорректный результат области.' unless %w[PASS ISSUES BLOCKED N/A].include?(check['status']) && check['evidence'].is_a?(String) && !check['evidence'].strip.empty?
    end
    findings = report.fetch('findings')
    raise 'findings должен быть массивом.' unless findings.is_a?(Array)
    findings.each do |finding|
      %w[problem file reason correction].each { |key| raise "У замечания нет #{key}." unless finding[key].is_a?(String) && !finding[key].strip.empty? }
      raise 'Нет признака исправления.' unless [true, false].include?(finding['fixed'])
      raise 'Аудит без --fix не может объявлять собственные исправления.' if !@fix && finding['fixed']
    end
    report
  end

  def write_report(report, checks, source_changed)
    status = report['status']
    status = 'ISSUES' if status == 'PASS' && (report['findings'].any? { |f| !f['fixed'] } || report['checks'].any? { |c| c['status'] == 'ISSUES' })
    status = 'BLOCKED' if report['checks'].any? { |c| c['status'] == 'BLOCKED' } || checks.any? { |c| !c['passed'] } || source_changed
    lines = ["# Проверка #{@mode}", '', "**#{status}** — #{report['summary']}", '', "Дата UTC: #{Time.now.utc.iso8601}. Platform set: #{@catalog.fetch('platform_set')}.", '', '## Проверенные исходники', '']
    @repositories.each { |root| lines << "- #{File.basename(root)}: #{git_revision(root)}" }
    lines += ['', '## Области', '']
    report['checks'].each { |check| lines << "- **#{check['area']} · #{check['status']}**: #{check['evidence']}" }
    lines += ['', '## Замечания', '']
    lines << 'Замечаний не найдено.' if report['findings'].empty?
    report['findings'].each do |finding|
      lines += ["- **#{finding['problem']}** — #{finding['file']}", "  Причина: #{finding['reason']}", "  Исправление: #{finding['correction']}", "  Статус: #{finding['fixed'] ? 'исправлено' : 'требует исправления'}."]
    end
    lines += ['', '## Независимые проверки', '']
    checks.each { |check| lines << "- #{check['repository']}: #{check['passed'] ? 'PASS' : 'FAIL'}; #{check['log']}; #{check['command'].join(' ')}" }
    lines << '- BLOCKED: исходники изменились в режиме аудита; изменения не откатывались.' if source_changed
    lines += ['', 'Сборка не подтверждает реальные платежи, внешний backend или визуальное соответствие дизайну.', '', '## Следующий шаг', '', report['next_step'], '']
    File.write(File.join(@output, 'latest.md'), lines.join("\n"))
    puts "#{status} · Отчёт: #{File.join(@output, 'latest.md')}"
    status == 'PASS' ? 0 : status == 'ISSUES' ? 1 : 2
  end

  def run
    return puts(prompt) if @print_prompt
    check_environment
    if @doctor
      puts "READY · #{@mode}; #{@fix ? 'исправления разрешены' : 'только аудит'}; #{@repositories.size} repositories; #{commands.size} проверки."
      puts "Отчёт: #{@output}/latest.md"
      return 0
    end
    FileUtils.mkdir_p(@output)
    lock = File.open(File.join(@output, 'run.lock'), 'w')
    raise 'Проверка этой цели уже запущена.' unless lock.flock(File::LOCK_EX | File::LOCK_NB)
    File.write(File.join(@output, 'latest.md'), "# RUNNING\n\nНовый запуск #{Time.now.utc.iso8601}. Итог ещё не получен.\n")
    baseline = snapshot
    checks = run_checks('before')
    File.write(File.join(@output, 'checks.json'), JSON.pretty_generate(checks))
    response = File.join(@output, 'response.json')
    FileUtils.rm_f(response)
    argv = ['codex', 'exec', '--ephemeral', '--sandbox', 'danger-full-access', '--cd', @root,
            '--output-schema', File.join(@platform, 'AgentChecks/ReviewReport.schema.json'), '--output-last-message', response, '-']
    puts "Агент проверяет #{@mode}: #{@fix ? 'с минимальными исправлениями' : 'без изменения исходников'}."
    IO.popen(argv, 'w') { |input| input.write(prompt) }
    raise 'Агент не завершил проверку. Предыдущий latest.md не является результатом этого запуска.' unless $?.success? && File.file?(response)
    report = validate_report(response)
    checks = run_checks('after') if @fix
    changed = !@fix && baseline != snapshot
    write_report(report, checks, changed)
  rescue StandardError => error
    if lock && lock.flock(File::LOCK_EX | File::LOCK_NB)
      File.write(File.join(@output, 'latest.md'), "# BLOCKED\n\n#{Time.now.utc.iso8601}: #{error.message}\n\nПроверьте локальные логи; PASS этого запуска не получен.\n")
    end
    raise
  ensure
    lock.close if lock
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    exit(BroadReview.new(ARGV).run || 0)
  rescue StandardError => error
    warn "BLOCKED · #{error.message}"
    exit 2
  end
end
