#!/usr/bin/env ruby

require "cgi"
require "fileutils"

root = File.expand_path("..", __dir__)
output = File.join(root, "Documentation", "Assets", "README")
FileUtils.mkdir_p(output)

colors = {
  core: "#3B82F6",
  extensions: "#8B5CF6",
  monetization: "#10B981",
  flows: "#EC4899",
  host: "#F59E0B",
  external: "#64748B",
}

specs = {
  "platform-module-selection" => {
    title: "Host app выбирает любой нужный модуль",
    subtitle: "Обязательного BroadPlatform нет; SwiftPM разрешает транзитивные dependencies",
    nodes: [
      ["HOST APP", "выбирает products", :host],
      ["EXTENSIONS", "standalone utility", :extensions],
      ["CORE", "foundation", :core],
      ["MONETIZATION", "Core + Adapty", :monetization],
      ["UI FLOWS", "Core + Monetization", :flows],
    ],
  },
  "federated-repositories" => {
    title: "Публичная федерация repositories",
    subtitle: "Код ревьюится и выпускается по модулям; integration фиксирует known-good set",
    nodes: [
      ["4 MODULE REPOS", "source + DocC + sandbox", :core],
      ["MODULE RELEASES", "independent SemVer", :monetization],
      ["INTEGRATION", "exact versions + example", :host],
      ["COMPATIBILITY", "machine-readable catalog", :flows],
      ["PUBLIC DOCS", "search + Edit this page", :extensions],
    ],
  },
  "module-release-flow" => {
    title: "Release одного модуля",
    subtitle: "Каждый шаг имеет свой PASS; catalog меняется только после integration gate",
    nodes: [
      ["CHANGE", "owner repository", :core],
      ["MODULE GATE", "build + probes + docs", :monetization],
      ["SEMVER TAG", "public release", :extensions],
      ["DEPENDENTS", "raise lower bound", :flows],
      ["CATALOG", "exact known-good set", :host],
    ],
  },
  "cross-repo-change" => {
    title: "Cross-repository change идёт снизу вверх",
    subtitle: "Сначала owner public API, затем consumers, integration evidence и public docs",
    nodes: [
      ["OWNER API", "minimal contract", :core],
      ["OWNER RELEASE", "standalone PASS", :monetization],
      ["CONSUMERS", "compatible range", :flows],
      ["INTEGRATION", "exact candidate set", :host],
      ["DOCS", "versions + why", :extensions],
    ],
  },
  "documentation-pipeline" => {
    title: "Документы остаются рядом с кодом",
    subtitle: "Сайт добавляет поиск и навигацию, но не заменяет versioned Markdown/DocC",
    nodes: [
      ["MARKDOWN + DOCC", "public source", :core],
      ["CONTENT CHECK", "links + contracts", :monetization],
      ["SITE BUILD", "search index", :flows],
      ["PUBLIC SITE", "anonymous access", :host],
      ["EDIT THIS PAGE", "public pull request", :extensions],
    ],
  },
  "repository-migration" => {
    title: "Порядок безопасной миграции",
    subtitle: "Переход к следующей фазе только после standalone и integration PASS",
    nodes: [
      ["BASELINE", "legacy gate", :external],
      ["CONTRACTS", "ADR + policy", :host],
      ["DOCS", "public site", :extensions],
      ["EXTENSIONS", "standalone", :extensions],
      ["CORE", "foundation", :core],
      ["MONETIZATION", "Core dependency", :monetization],
      ["UI FLOWS", "upper layer", :flows],
      ["CUTOVER", "clean-clone acceptance", :host],
    ],
  },
}

themes = {
  "light" => { bg: "#F8FAFC", card: "#FFFFFF", text: "#0F172A", muted: "#64748B", line: "#CBD5E1" },
  "dark" => { bg: "#08111F", card: "#111C2F", text: "#F8FAFC", muted: "#9FB0C7", line: "#33445F" },
}

def text(value)
  CGI.escapeHTML(value)
end

specs.each do |name, spec|
  themes.each do |theme_name, theme|
    nodes = spec.fetch(:nodes)
    margin = 54.0
    gap = nodes.length > 6 ? 12.0 : 18.0
    card_width = (1200.0 - margin * 2 - gap * (nodes.length - 1)) / nodes.length
    card_y = 205
    card_height = 190

    svg = []
    svg << %(<?xml version="1.0" encoding="UTF-8"?>)
    svg << %(<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="540" viewBox="0 0 1200 540" role="img" aria-labelledby="title desc">)
    svg << %(<title id="title">#{text(spec.fetch(:title))}</title>)
    svg << %(<desc id="desc">#{text(spec.fetch(:subtitle))}</desc>)
    svg << %(<rect width="1200" height="540" rx="28" fill="#{theme[:bg]}"/>)
    svg << %(<path d="M54 150H1146" stroke="#{theme[:line]}" stroke-width="1"/>)
    svg << %(<text x="54" y="70" fill="#{theme[:text]}" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif" font-size="34" font-weight="750">#{text(spec.fetch(:title))}</text>)
    svg << %(<text x="54" y="112" fill="#{theme[:muted]}" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif" font-size="17">#{text(spec.fetch(:subtitle))}</text>)

    nodes.each_with_index do |(label, description, color_key), index|
      x = margin + index * (card_width + gap)
      color = colors.fetch(color_key)
      if index < nodes.length - 1
        arrow_start = x + card_width + 4
        arrow_end = x + card_width + gap - 4
        svg << %(<path d="M#{arrow_start.round(1)} 300H#{arrow_end.round(1)}" stroke="#{theme[:line]}" stroke-width="2"/>)
        svg << %(<path d="M#{(arrow_end - 7).round(1)} 294L#{arrow_end.round(1)} 300L#{(arrow_end - 7).round(1)} 306" fill="none" stroke="#{theme[:line]}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>)
      end
      svg << %(<rect x="#{x.round(1)}" y="#{card_y}" width="#{card_width.round(1)}" height="#{card_height}" rx="18" fill="#{theme[:card]}" stroke="#{theme[:line]}"/>)
      svg << %(<rect x="#{(x + 18).round(1)}" y="#{card_y + 20}" width="42" height="8" rx="4" fill="#{color}"/>)
      svg << %(<text x="#{(x + 18).round(1)}" y="#{card_y + 76}" fill="#{theme[:text]}" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif" font-size="#{nodes.length > 6 ? 15 : 17}" font-weight="750">#{text(label)}</text>)
      description.split(" ").each_slice(nodes.length > 6 ? 2 : 3).with_index do |words, line_index|
        svg << %(<text x="#{(x + 18).round(1)}" y="#{card_y + 112 + line_index * 23}" fill="#{theme[:muted]}" font-family="-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif" font-size="13">#{text(words.join(" "))}</text>)
      end
      svg << %(<text x="#{(x + 18).round(1)}" y="#{card_y + 166}" fill="#{color}" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="10" font-weight="700">#{format('%02d', index + 1)}</text>)
    end

    svg << %(<text x="54" y="476" fill="#{theme[:muted]}" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="11" letter-spacing="1.6">BROADAPPS IOS · PUBLIC MODULE ARCHITECTURE</text>)
    svg << %(<circle cx="1134" cy="472" r="7" fill="#10B981"/><text x="1113" y="503" fill="#{theme[:muted]}" text-anchor="end" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="10">CHECKED FLOW</text>)
    svg << %(</svg>)

    File.write(File.join(output, "#{name}-#{theme_name}.svg"), svg.join("\n") + "\n")
  end
end

puts "Generated #{specs.length * themes.length} federation diagrams."
