#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "pathname"
require "tmpdir"
require "time"

begin
  require "xcodeproj"
rescue LoadError
  abort "Не найден Ruby gem xcodeproj. Установите CocoaPods и повторите команду."
end

module ReleaseExport
  ROOT = File.expand_path("..", __dir__)
  INTERNAL = %w[
    broad-core-ios broad-extensions-ios broad-monetization-ios
    broad-ui-flows-ios broad-ru-billing-ios
  ].freeze
  REPO_URL = %r{\Ahttps://github\.com/BroadApps-official/(#{INTERNAL.join('|')})(?:\.git)?\z}i
  MANIFEST_DEPENDENCY = %r{\.package\(\s*url:\s*"https://github\.com/BroadApps-official/(#{INTERNAL.join('|')})(?:\.git)?"\s*,\s*(?:exact|from):\s*"[^"]+"\s*\)}m
  BROAD_GIT_NEEDLES = ["github.com/broadapps-official", "git@github.com:broadapps-official"].freeze

  class Error < StandardError; end

  class Runner
    def initialize(argv)
      @options = { project: nil, scheme: nil, output: nil, source_root: nil, audit: nil,
                   release_config: "Scripts/codemagic.release.yaml", export_only: false,
                   no_push: false, skip_build: false, allow_dirty: false }
      parser = OptionParser.new do |opts|
        opts.banner = "Использование: bash Scripts/prepare_release.sh [версия] [параметры]"
        opts.on("--project PATH") { |value| @options[:project] = value }
        opts.on("--scheme NAME") { |value| @options[:scheme] = value }
        opts.on("--output PATH") { |value| @options[:output] = value }
        opts.on("--audit PATH", "Повторно проверить готовый релизный проект") { |value| @options[:audit] = value }
        opts.on("--release-config PATH", "Codemagic-конфигурация релизной ветки") { |value| @options[:release_config] = value }
        opts.on("--export-only", "Создать только локальную копию, без ветки") { @options[:export_only] = true }
        opts.on("--no-push", "Создать ветку локально, не отправляя в GitHub") { @options[:no_push] = true }
        opts.on("--source-root PATH", "Локальные репозитории пакетов для проверки") { |value| @options[:source_root] = value }
        opts.on("--skip-build", "Только подготовка проекта") { @options[:skip_build] = true }
        opts.on("--allow-dirty", "Только для локальной проверки незакоммиченных правок") { @options[:allow_dirty] = true }
      end
      parser.parse!(argv)
      @options[:version] = argv.shift
      raise Error, "Укажите --project и --scheme." unless @options[:project] && @options[:scheme]
      raise Error, "Неизвестные аргументы: #{argv.join(' ')}" unless argv.empty?
    end

    def run
      if @options[:audit]
        audit_source!(File.expand_path(@options[:audit], ROOT))
        puts "Проверка релизного проекта пройдена: ссылок на Git BroadApps нет."
        return
      end
      check_source!
      original_project = Xcodeproj::Project.open(File.join(ROOT, @options[:project]))
      @options[:version] ||= app_version(original_project)
      version = @options[:version]
      raise Error, "Версия должна иметь формат 1.2.3." unless version.match?(/\A\d+\.\d+\.\d+\z/)
      raise Error, "Версия приложения в Xcode не равна #{version}." unless app_version(original_project) == version
      unless @options[:export_only]
        config = File.expand_path(@options[:release_config], ROOT)
        raise Error, "Не найдена релизная конфигурация Codemagic: #{config}." unless File.file?(config)
        branch = "release/#{version}"
        branch_dir = File.join(ROOT, "ReleaseBranches", version)
        raise Error, "Релизная ветка #{branch} уже есть локально." if branch_exists?(branch)
        raise Error, "Папка релизной ветки уже существует: #{branch_dir}." if File.exist?(branch_dir)
        if !@options[:no_push] && remote_branch_exists?(branch)
          raise Error, "В GitHub уже есть #{branch}. Не перезаписывайте её; выпустите новую версию."
        end
      end

      output = File.expand_path(@options[:output] || File.join("ReleaseExport", version), ROOT)
      raise Error, "Папка #{output} уже существует. Проверьте её или удалите перед повторным запуском." if File.exist?(output)
      raise Error, "Выходная папка должна быть внутри ReleaseExport/." unless output.start_with?(File.join(ROOT, "ReleaseExport") + File::SEPARATOR)

      FileUtils.mkdir_p(File.dirname(output))
      staging = Dir.mktmpdir(".release-", File.dirname(output))
      branch_snapshot = nil
      begin
        puts "Подготовка #{version}: копирую исходники приложения…"
        copy_app(staging)
        project = Xcodeproj::Project.open(File.join(staging, @options[:project]))
        pins = resolved_pins(staging)
        refs = project.root_object.package_references.select { |ref| ref.isa == "XCRemoteSwiftPackageReference" && internal_identity(ref.repositoryURL) }
        raise Error, "В Xcode-проекте нет пакетов BroadApps." if refs.empty?
        refs.each do |ref|
          identity = internal_identity(ref.repositoryURL)
          requirement = ref.requirement
          pin = requirement["kind"] == "exactVersion" ? requirement["version"] : pins[identity]
          unless pin
            pins.merge!(resolve_remote_pins!(staging))
            pin = pins[identity]
          end
          raise Error, "Для #{identity} нет точной версии. Закрепите её в Xcode или сохраните Package.resolved." unless pin&.match?(/\A\d+\.\d+\.\d+\z/)
          pins[identity] = pin
        end

        package_commits = {}
        queue = refs.map { |ref| internal_identity(ref.repositoryURL) }.uniq
        until queue.empty?
          identity = queue.shift
          next if package_commits.key?(identity)
          version_pin = pins[identity]
          unless version_pin
            pins.merge!(resolve_remote_pins!(staging))
            version_pin = pins[identity]
          end
          raise Error, "Для вложенного пакета #{identity} нет точной версии в Package.resolved." unless version_pin
          package_dir = File.join(staging, "LocalPlatform", identity)
          commit = copy_package(identity, version_pin, package_dir)
          package_commits[identity] = { "version" => version_pin, "commit" => commit }
          manifest = File.join(package_dir, "Package.swift")
          source = File.read(manifest)
          nested = source.scan(MANIFEST_DEPENDENCY).flatten.uniq
          nested.each { |name| queue << name unless package_commits.key?(name) }
          source = source.gsub(MANIFEST_DEPENDENCY) { ".package(path: \"../#{Regexp.last_match(1)}\")" }
          File.write(manifest, source)
        end

        stable_ids = {}
        refs.each do |remote|
          identity = internal_identity(remote.repositoryURL)
          local = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
          stable_ids[local.uuid] = Digest::SHA256.hexdigest("broadapps-local-package:#{identity}")[0, 24].upcase
          local.relative_path = "LocalPlatform/#{identity}"
          project.root_object.package_references << local
          project.objects.grep(Xcodeproj::Project::Object::XCSwiftPackageProductDependency).each do |product|
            product.package = local if product.package == remote
          end
          project.root_object.package_references.delete(remote)
          remote.remove_from_project
        end
        project.save
        pbxproj = File.join(staging, @options[:project], "project.pbxproj")
        serialized = File.read(pbxproj)
        stable_ids.each do |generated, stable|
          raise Error, "Конфликт идентификаторов Xcode для #{stable}." if serialized.include?(stable)
          serialized = serialized.gsub(generated, stable)
        end
        serialized.sub!(%r{(/\* Begin XCLocalSwiftPackageReference section \*/\n)(.*?)(/\* End XCLocalSwiftPackageReference section \*/)}m) do
          prefix, body, suffix = Regexp.last_match.captures
          entries = body.scan(/^\t\t[0-9A-F]{24}.*?^\t\t};\n/m)
          raise Error, "Не удалось упорядочить локальные пакеты Xcode." unless entries.join == body
          prefix + entries.sort.join + suffix
        end
        File.write(pbxproj, serialized)
        Dir.glob(File.join(staging, "**", "Package.resolved")).each { |path| File.delete(path) }
        audit_source!(staging)

        unless @options[:skip_build]
          unless @options[:export_only]
            branch_snapshot = Dir.mktmpdir(".release-branch-", File.dirname(output))
            FileUtils.cp_r(Dir.children(staging).map { |name| File.join(staging, name) }, branch_snapshot)
          end
          puts "Разрешаю сторонние зависимости и проверяю сборку…"
          verify_build!(staging)
        end
        FileUtils.mv(staging, output)
        record = {
          "app" => File.basename(ROOT), "version" => version,
          "app_commit" => capture!("git", "-C", ROOT, "rev-parse", "HEAD").strip,
          "source_dirty" => @options[:allow_dirty],
          "platform_packages" => package_commits.sort.to_h,
          "source_check" => "passed", "build_check" => @options[:skip_build] ? "skipped" : "passed",
          "created_at" => Time.now.utc.iso8601
        }
        records = File.join(ROOT, "ReleaseRecords")
        FileUtils.mkdir_p(records)
        File.write(File.join(records, "#{version}.json"), JSON.pretty_generate(record) + "\n")
        puts "Готово. Релизный проект: #{output}"
        puts "Ссылок на Git BroadApps в релизном проекте нет."
        create_release_branch!(branch_snapshot || output, version, record) unless @options[:export_only]
      ensure
        FileUtils.remove_entry(staging) if File.exist?(staging)
        FileUtils.remove_entry(branch_snapshot) if branch_snapshot && File.exist?(branch_snapshot)
      end
    rescue Error => e
      warn "Ошибка подготовки релиза: #{e.message}"
      exit 1
    end

    private

    def capture!(*command, chdir: nil)
      output, status = chdir ? Open3.capture2e(*command, chdir: chdir) : Open3.capture2e(*command)
      unless status.success?
        excerpt = output.tr("\r", "\n").lines.last(18).join
        raise Error, "Команда #{command.first} завершилась с ошибкой:\n#{excerpt[-4000, 4000]}"
      end
      output
    end

    def check_source!
      git_root = capture!("git", "-C", ROOT, "rev-parse", "--show-toplevel").strip
      raise Error, "Запустите команду из Git-репозитория приложения." unless git_root == ROOT
      return if @options[:allow_dirty]
      dirty = capture!("git", "-C", ROOT, "status", "--porcelain", "--untracked-files=normal")
      raise Error, "Сначала сохраните изменения приложения в коммит. Для пробного запуска есть --allow-dirty." unless dirty.empty?
    end

    def app_version(project)
      app_targets = project.targets.select { |target| target.product_type == "com.apple.product-type.application" }
      values = app_targets.flat_map { |target| target.build_configurations.map { |config| config.build_settings["MARKETING_VERSION"] } }.compact.uniq
      raise Error, "Укажите одинаковый MARKETING_VERSION во всех конфигурациях app target в Xcode." unless values.length == 1
      values.first
    end

    def copy_app(destination)
      paths = capture!("git", "-C", ROOT, "ls-files", "-z").split("\0")
      paths.each do |relative|
        next if relative.start_with?("docs/", ".github/", "Scripts/prepare_release")
        next if relative.split("/").any? { |part| %w[xcuserdata xcuserdatad].include?(part) }
        next if %w[Scripts/check_release_artifact.rb Scripts/check_release_source.rb Scripts/codemagic.release.yaml].include?(relative)
        next if %w[codemagic.yaml .gitignore project.yml].include?(relative)
        next if %w[README.md README.dev.md CONTRIBUTING.md CHANGELOG.md].include?(relative)
        source = File.join(ROOT, relative)
        raise Error, "Не найден отслеживаемый файл #{relative}." unless File.file?(source)
        target = File.join(destination, relative)
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp(source, target)
      end
    end

    def resolved_pins(root)
      pins = {}
      Dir.glob(File.join(root, "**", "Package.resolved")).each do |path|
        JSON.parse(File.read(path)).fetch("pins", []).each do |pin|
          identity = pin["identity"]
          pins[identity] = pin.dig("state", "version") if INTERNAL.include?(identity)
        end
      end
      pins
    end

    def resolve_remote_pins!(root)
      puts "Определяю точные версии вложенных пакетов…"
      capture!("xcodebuild", "-resolvePackageDependencies", "-project", File.join(root, @options[:project]),
               "-scheme", @options[:scheme])
      resolved_pins(root)
    end

    def internal_identity(url)
      url.to_s.match(REPO_URL)&.captures&.first
    end

    def copy_package(identity, version, destination)
      local = @options[:source_root] && File.join(File.expand_path(@options[:source_root]), identity)
      if local && File.directory?(File.join(local, ".git"))
        repository = local
      else
        temporary_repository = Dir.mktmpdir("#{identity}-")
        repository = temporary_repository
        capture!("git", "clone", "--quiet", "--depth", "1", "--branch", version,
                 "https://github.com/BroadApps-official/#{identity}.git", repository)
      end
      commit = capture!("git", "-C", repository, "rev-parse", "refs/tags/#{version}^{commit}").strip
      FileUtils.mkdir_p(destination)
      archive = File.join(Dir.tmpdir, "#{identity}-#{Process.pid}.tar")
      begin
        root_files = capture!("git", "-C", repository, "ls-tree", "--name-only", version).lines.map(&:strip)
        legal_files = root_files.grep(/\A(?:LICENSE|LICENCE|NOTICE|COPYING)(?:[.-].*)?\z/i)
        capture!("git", "-C", repository, "archive", "--format=tar", "--output=#{archive}", version,
                 "Package.swift", "Sources", *legal_files)
        capture!("tar", "-xf", archive, "-C", destination)
      ensure
        File.delete(archive) if File.exist?(archive)
      end
      commit
    ensure
      FileUtils.remove_entry(temporary_repository) if temporary_repository && File.directory?(temporary_repository)
    end

    def audit_source!(root)
      raise Error, "Не найден релизный Xcode-проект: #{root}" unless File.file?(File.join(root, @options[:project], "project.pbxproj"))
      Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH).each do |path|
        relative = Pathname.new(path).relative_path_from(Pathname.new(root)).to_s
        raise Error, "В релизном проекте остался .git: #{relative}" if File.basename(path) == ".git"
        next unless File.file?(path)
        raise Error, "В релизном проекте осталась ссылка на Git BroadApps: #{relative}" if broad_git_link?(path)
      end
    end

    def broad_git_link?(path)
      File.open(path, "rb") do |file|
        remainder = "".b
        while (chunk = file.read(1024 * 1024))
          text = (remainder + chunk).downcase
          return true if BROAD_GIT_NEEDLES.any? { |needle| text.include?(needle) }
          remainder = text.byteslice(-64, 64) || "".b
        end
      end
      false
    end

    def verify_build!(root)
      project = File.join(root, @options[:project])
      capture!("xcodebuild", "-resolvePackageDependencies", "-project", project, "-scheme", @options[:scheme])
      if File.file?(File.join(root, "Podfile"))
        capture!("pod", "install", "--deployment", chdir: root)
        workspace = Dir.glob(File.join(root, "*.xcworkspace")).first
        raise Error, "CocoaPods не создал .xcworkspace." unless workspace
        source_arg = ["-workspace", workspace]
      else
        source_arg = ["-project", project]
      end
      capture!("xcodebuild", *source_arg, "-scheme", @options[:scheme], "-configuration", "Release",
               "-destination", "generic/platform=iOS", "CODE_SIGNING_ALLOWED=NO", "build")
      audit_source!(root)
    end

    def branch_exists?(branch)
      _output, status = Open3.capture2e("git", "-C", ROOT, "show-ref", "--verify", "--quiet", "refs/heads/#{branch}")
      status.success?
    end

    def remote_branch_exists?(branch)
      !capture!("git", "-C", ROOT, "ls-remote", "--heads", "origin", "refs/heads/#{branch}").strip.empty?
    end

    def create_release_branch!(output, version, record)
      branch = "release/#{version}"
      checkout = File.join(ROOT, "ReleaseBranches", version)
      FileUtils.mkdir_p(File.dirname(checkout))
      capture!("git", "-C", ROOT, "worktree", "add", "--orphan", "-b", branch, checkout)
      FileUtils.cp_r(Dir.children(output).map { |name| File.join(output, name) }, checkout)
      FileUtils.cp(File.expand_path(@options[:release_config], ROOT), File.join(checkout, "codemagic.yaml"))
      scripts = File.join(checkout, "Scripts")
      FileUtils.mkdir_p(scripts)
      %w[check_release_source.rb check_release_artifact.rb].each do |name|
        FileUtils.cp(File.join(ROOT, "Scripts", name), File.join(scripts, name))
      end
      capture!("ruby", File.join(scripts, "check_release_source.rb"), checkout)
      capture!("git", "-C", checkout, "add", "-A")
      capture!("git", "-C", checkout, "diff", "--cached", "--check")
      capture!("git", "-C", checkout, "commit", "-m", "Release #{version} with local platform packages")
      record["release_branch"] = branch
      record["release_commit"] = capture!("git", "-C", checkout, "rev-parse", "HEAD").strip
      File.write(File.join(ROOT, "ReleaseRecords", "#{version}.json"), JSON.pretty_generate(record) + "\n")
      puts "Релизная ветка готова: #{branch} (#{checkout})"
      if @options[:no_push]
        puts "Пробный запуск: отправка ветки в GitHub пропущена."
      else
        begin
          capture!("git", "-C", ROOT, "push", "--set-upstream", "origin", branch)
        rescue Error => e
          raise Error, "#{e.message}\nВетка сохранена локально. После получения доступа: git push origin #{branch}"
        end
        puts "Ветка #{branch} отправлена в GitHub. Выберите её в Codemagic и запустите сборку вручную."
      end
    end
  end
end

ReleaseExport::Runner.new(ARGV).run
