# frozen_string_literal: true

require "open_project/thematiq/version"
require "open_project/thematiq/contrast"
require "open_project/thematiq/editor"
require "open_project/thematiq/tokens"

module OpenProject
  module Thematiq
    # Evidence of contrast for an audit: every design system that is in use, each pair of text and background the
    # shell draws, light and dark, with its ratio and verdict against WCAG 2.1 success criterion 1.4.3 (4.5 to 1).
    # And the two documents generated from the code, so they cannot drift: the contrast of every shipped set, and
    # the reference of every token. No Rails here.
    module Compliance
      CRITERION = "WCAG 2.1 SC 1.4.3 Contrast (Minimum), AA, 4.5 to 1"

      module_function

      # in_use: [[token set, where]] - where says what uses it: "instance", "project demo-project", "module meetings".
      def report(in_use, generated_at:)
        systems = in_use.group_by { |token_set, _where| token_set.id }.map do |_id, uses|
          token_set = uses.first.first
          light = pairs(Contrast.report(token_set))
          dark = Contrast.dark_report(token_set)
          { "id" => token_set.id, "name" => token_set.name, "used_by" => uses.map(&:last).uniq,
            "light" => light, "dark" => dark ? pairs(dark) : nil,
            "dark_used" => Contrast.dark_usable?(token_set),
            "passes" => (light + (dark ? pairs(dark) : [])).none? { |pair| pair["verdict"] == "fail" } }
        end
        { "criterion" => CRITERION, "minimum" => Contrast::MINIMUM, "generated_at" => generated_at, "plugin_version" => VERSION,
          "passes" => systems.all? { |system| system["passes"] }, "design_systems" => systems }
      end

      def pairs(report)
        report.map do |pair, ratio|
          { "pair" => pair, "ratio" => ratio,
            "verdict" => if ratio.nil? then "unknown" elsif ratio >= Contrast::MINIMUM then "pass" else "fail" end }
        end
      end

      # --- the generated documents ---

      PAIR_ORDER = %w[on-primary on-action ink-on-ground muted-on-ground link-on-white primary-deep-on-primary-light text-on-menu].freeze

      # docs/contrast-report.md: the contrast of every design system that ships with the plugin.
      def contrast_document(catalogue)
        rows = catalogue.sets.map do |token_set|
          report = Contrast.report(token_set)
          cells = PAIR_ORDER.map { |pair| report.key?(pair) ? format_ratio(report[pair]) : "" }
          dark = Contrast.dark_failures(token_set)
          dark_cell = if !token_set.dark? then "no dark block" elsif dark.empty? then "all pass" else "under 4.5: #{dark.join(', ')}" end
          "| #{token_set.name} (`#{token_set.id}`) | #{cells.join(' | ')} | #{dark_cell} |"
        end
        <<~MARKDOWN
          # Contrast of the shipped design systems

          Generated from the catalogue by `script/generate-docs.rb`. Do not edit by hand: `test/generated_docs_test.rb` fails when this page and the catalogue disagree.

          Each column is a pair of text and background the shell draws, measured as WCAG 2.1 contrast. 4.5 to 1 is needed (#{CRITERION}). A value under it is marked with an asterisk. An empty cell: the set has no menu colour.

          | Design system | #{PAIR_ORDER.join(' | ')} | Dark theme |
          |---|#{(['---'] * PAIR_ORDER.size).join('|')}|---|
          #{rows.join("\n")}
        MARKDOWN
      end

      def format_ratio(ratio)
        return "unknown" if ratio.nil?

        text = format("%.2f", ratio)
        ratio < Contrast::MINIMUM ? "#{text}*" : text
      end

      # docs/token-reference.md: every value a design system can hold, its CSS name, its kind and where it shows.
      def token_document(labels)
        roles = Tokens::TokenSet::ALL_KINDS.map do |key, kind|
          "| `#{key}` | `--thematiq-#{key == 'font-family' ? 'font' : key}` | #{kind} | #{labels.fetch(key, '')} |"
        end
        vocabulary = Editor::VOCABULARY_GROUPS.flat_map do |group|
          group.keys.map do |key|
            "| `#{key}` | `#{Tokens::Vocabulary.css_name(key)}` | #{Tokens::Vocabulary::KINDS[key]} | #{group.id} | " \
              "#{Tokens::Vocabulary.drawn?(key) ? 'drawn' : 'carried'} |"
          end
        end
        <<~MARKDOWN
          # Token reference

          Generated from the code by `script/generate-docs.rb`. Do not edit by hand: `test/generated_docs_test.rb` fails when this page and the code disagree.

          ## The roles

          #{Tokens::TokenSet::KINDS.size} values every design system has, and `menu`, which is optional. [tokens.md](tokens.md) says how they reach the page.

          | Role | Alias for other plugins | Kind | Used for |
          |---|---|---|---|
          #{roles.join("\n")}

          ## thematiq's full vocabulary

          #{Tokens::Vocabulary::KINDS.size} values under thematiq's own names, optional. "Drawn" values reach OpenProject's or Primer's variables; "carried" values travel through export, import and Figma and are kept, but OpenProject has no place for them. A value a design system leaves out keeps OpenProject's own value.

          | Key | thematiq's CSS name | Kind | Group in the editor | In OpenProject |
          |---|---|---|---|---|
          #{vocabulary.join("\n")}
        MARKDOWN
      end
    end
  end
end
