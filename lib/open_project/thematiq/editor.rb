# frozen_string_literal: true

require "open_project/thematiq/tokens"
require "open_project/thematiq/contrast"

module OpenProject
  module Thematiq
    # What the style editor needs to know about the tokens: how they are grouped, and which contrast
    # checks belong next to which colour. The page and its script both read this, so they cannot drift.
    #
    # The groups follow the four tabs of thematiq's token editor: branding, content area, buttons and
    # typography. A new group is one more entry in GROUPS with its text in en.yml. Nothing else changes.
    # The vocabulary adds a group per part of thematiq's full vocabulary, by VOCABULARY_RULES.
    module Editor
      # vocabulary: true for a group of thematiq's full vocabulary. Those start closed, under "More values".
      Group = Struct.new(:id, :keys, :vocabulary, keyword_init: true)

      # The vocabulary in groups, by the start of a key. The first rule that matches decides.
      VOCABULARY_RULES = [
        ["status", /\A(?:color-(?:error|warning|success|info|favorite)|component-status-badge-)/],
        ["links", /\A(?:color-link-|component-link-)/],
        ["text", /\A(?:color-(?:text-light|primary-text|primary-light-hover|placeholder-)|component-(?:paragraph|ordered-list|unordered-list)-)/],
        ["surfaces", /\A(?:color-(?:background-darker|surface)|component-(?:separator|content)-)/],
        ["focus", /\Acolor-focus/],
        ["radii", /\Aborder-radius-/],
        ["controls", /\A(?:color-button-|color-action-text|component-button-)/],
        ["forms", /\Acomponent-(?:textbox|form)-/],
        ["table", /\Acomponent-table-/],
        ["headings", /\A(?:component-heading-|body-font-family)/],
        ["motion", /\Aanimation-/],
        ["header", /\A(?:color-header-|header-|color-nav-|nav-link-|component-navigation-|component-badge-)/],
        ["brand", /\A(?:logo-|size-lint|color-logo-|brand-stripe-|color-accent-|color-footer-)/],
        ["website", /\A(?:login-|hero-|website-)/]
      ].freeze

      def self.vocabulary_group_of(key)
        VOCABULARY_RULES.find { |_id, pattern| pattern.match?(key) }&.first
      end

      VOCABULARY_GROUPS = VOCABULARY_RULES.map do |id, _pattern|
        Group.new(id:, keys: Tokens::Vocabulary.keys.select { |key| vocabulary_group_of(key) == id }.freeze, vocabulary: true)
      end.freeze

      GROUPS = ([
        Group.new(id: "branding", keys: %w[primary primary-deep primary-light accent], vocabulary: false),
        Group.new(id: "content", keys: %w[ground soft chip line field menu radius radius-lg], vocabulary: false),
        Group.new(id: "buttons", keys: %w[action action-deep link], vocabulary: false),
        Group.new(id: "typography", keys: %w[ink text muted font-family], vocabulary: false),
        Group.new(id: "pdf_export", keys: %w[pdf-cover-text], vocabulary: false)
      ] + VOCABULARY_GROUPS).freeze

      # Every key the form has a field for, with its kind: the roles, then the vocabulary.
      KINDS = Tokens::TokenSet::ALL_KINDS.merge(Tokens::Vocabulary::KINDS).freeze

      # Every key with a dark field: each colour, roles and vocabulary alike. Left empty, the dark theme keeps the dark
      # value of the base, else OpenProject's own. Nothing is derived from the light value.
      DARK_FIELDS = (KINDS.select { |_key, kind| kind == :color }.keys - Tokens::TokenSet::PRINT_KEYS).freeze

      # One contrast check the shell draws: the text, what it sits on, and the tokens it is shown next to.
      # A name that starts with "@" is a colour the plugin works out itself, see Preview#derived.
      Check = Struct.new(:id, :foreground, :background, :tokens, keyword_init: true)

      CHECKS = [
        Check.new(id: "on-primary", foreground: "@on-primary", background: "primary", tokens: %w[primary]),
        Check.new(id: "on-action", foreground: "@on-action", background: "action", tokens: %w[action]),
        Check.new(id: "ink-on-ground", foreground: "ink", background: "ground", tokens: %w[ink ground]),
        Check.new(id: "muted-on-ground", foreground: "muted", background: "ground", tokens: %w[muted ground]),
        Check.new(id: "link-on-white", foreground: "link", background: "#ffffff", tokens: %w[link]),
        Check.new(id: "primary-deep-on-primary-light", foreground: "@on-selected", background: "primary-light",
                  tokens: %w[primary-deep primary-light]),
        Check.new(id: "text-on-menu", foreground: "@on-menu", background: "menu", tokens: %w[menu])
      ].freeze

      SCRIPT_PATH = File.expand_path("editor/assets/editor.js", __dir__)
      COMPARE_SCRIPT_PATH = File.expand_path("editor/assets/compare.js", __dir__)

      module_function

      def groups
        GROUPS
      end

      def group(id)
        GROUPS.find { |group| group.id == id }
      end

      # The keys of one group, or none for an id that is not a group. Never a key from outside.
      def keys_of(id)
        group(id.to_s)&.keys || []
      end

      def checks_for(key)
        CHECKS.select { |check| check.tokens.include?(key) }
      end

      # The ratio of one check for a token set. nil when it cannot be measured, or does not apply:
      # the menu check only counts for a set that has a menu colour.
      def ratio(check, token_set)
        return nil if check.id == "text-on-menu" && token_set["menu"].nil?

        Contrast.report(token_set)[check.id]
      end

      # "pass", "fail" or "unknown". Unknown is never shown as fine.
      def verdict(ratio)
        return "unknown" if ratio.nil?

        ratio >= Contrast::MINIMUM ? "pass" : "fail"
      end

      # What the script needs: the kinds, the checks and the named colours the validator accepts.
      # All of it is the plugin's own data. Nothing an administrator typed is in here.
      def script_data
        { "kinds" => KINDS.transform_values(&:to_s),
          "preview" => Tokens::TokenSet::ALL_KINDS.keys,
          "checks" => CHECKS.map { |check| { "id" => check.id, "foreground" => check.foreground, "background" => check.background } },
          "named" => Tokens::Validator::NAMED_COLORS,
          "minimum" => Contrast::MINIMUM }
      end

      # The script of the live preview. It is inlined with OpenProject's nonce, like the project menu's.
      def script
        @script ||= File.read(SCRIPT_PATH)
      end

      # The script of the apply dialog: the boxes repaint the picture, and Apply repaints the page without a reload.
      def compare_script
        @compare_script ||= File.read(COMPARE_SCRIPT_PATH)
      end
    end
  end
end
