# frozen_string_literal: true

require "json"
require "open_project/thematiq/tokens"
require "open_project/thematiq/version"

module OpenProject
  module Thematiq
    # Download and upload of a design system as a Figma token set. Three formats:
    #
    #   dtcg                  W3C Design Tokens, version 2025.10: "$value" and "$type", colours as objects.
    #                         The layout thematiq writes, so a file from one opens in the other.
    #   tokens-studio         Tokens Studio for Figma, one file, with "$themes" and "$metadata", "$value" spelling.
    #   tokens-studio-legacy  The same with the older "value" and "type" spelling.
    #
    # The names and paths are thematiq's. A role is written under the CSS name thematiq reads that role from
    # (its ShellRoleMapper), at the path thematiq's DesignTokensWriter gives that name: the first segment,
    # the second, then the rest joined by dashes. Every token carries its CSS name in
    # $extensions["nl.conduction.thematiq"].cssVariable, which is what thematiq's import looks at first.
    #
    # docs/figma.md has the tables. Figma::Reader reads a file back.
    module Figma
      EXTENSION = "nl.conduction.thematiq"
      PLUGIN_EXTENSION = "nl.conduction.openproject-thematiq"
      FORMATS = %w[dtcg tokens-studio tokens-studio-legacy].freeze

      # The CSS name each role is written under. Sixteen are thematiq's own names. "text" and "menu" have no
      # counterpart in thematiq's role mapper, so they get names in the plugin's own space. thematiq skips them.
      WRITE_NAMES = {
        "primary" => "--nldesign-color-primary", "primary-deep" => "--nldesign-color-primary-hover",
        "primary-light" => "--nldesign-color-primary-light", "action" => "--nldesign-color-action",
        "action-deep" => "--nldesign-color-action-hover", "link" => "--nldesign-color-link",
        "accent" => "--nldesign-color-accent", "ink" => "--nldesign-color-text", "text" => "--thematiq-shell-text",
        "muted" => "--nldesign-color-text-muted", "line" => "--nldesign-color-border",
        "soft" => "--nldesign-color-background-dark", "ground" => "--nldesign-color-background",
        "chip" => "--nldesign-color-background-hover", "field" => "--nldesign-color-border-dark",
        "radius" => "--nldesign-border-radius", "radius-lg" => "--nldesign-border-radius-large",
        "font-family" => "--nldesign-font-family", "menu" => "--thematiq-shell-menu"
      }.freeze

      # The CSS names each role is read from, first match wins. The lists are thematiq's ShellRoleMapper::SOURCES,
      # in its order, with the plugin's own name in front. thematiq's worked out values (a darker hover, a mix)
      # are not copied: a role the file does not name keeps the value of the base design system.
      READ_NAMES = {
        "primary" => %w[--color-primary --summer-color-primary --nldesign-color-primary],
        "primary-deep" => %w[--color-primary-hover --summer-color-primary-hover --nldesign-color-primary-hover],
        "primary-light" => %w[--color-primary-light --summer-color-primary-light --nldesign-color-primary-light],
        "action" => %w[--color-primary-element --nldesign-color-action --summer-color-primary --nldesign-color-primary],
        "action-deep" => %w[--color-primary-element-hover --nldesign-color-action-hover],
        "link" => %w[--summer-color-primary --nldesign-color-link],
        "accent" => %w[--nldesign-color-accent --color-error --summer-color-error --nldesign-color-error],
        "ink" => %w[--color-main-text --summer-color-text --nldesign-color-text],
        "text" => %w[--thematiq-shell-text],
        "muted" => %w[--color-text-maxcontrast --summer-color-text-muted --nldesign-color-text-muted],
        "line" => %w[--color-border --summer-color-border --nldesign-color-border],
        "soft" => %w[--color-background-dark --summer-color-background-dark --nldesign-color-background-dark],
        "ground" => %w[--nldesign-component-content-surface-background-color --summer-color-background-plain
                       --nldesign-color-background],
        "chip" => %w[--color-background-hover --summer-color-background-hover --nldesign-color-background-hover],
        "field" => %w[--color-border-maxcontrast --summer-color-border-input --nldesign-color-border-dark],
        "radius" => %w[--border-radius --summer-radius --nldesign-border-radius],
        "radius-lg" => %w[--border-radius-large --summer-radius-large --nldesign-border-radius-large],
        "font-family" => %w[--font-face --summer-font-family --nldesign-font-family],
        "menu" => %w[--thematiq-shell-menu]
      }.freeze

      # For a file without the extension: the end of a token's path names the CSS name. The longest end wins.
      # This is the table of thematiq's DesignTokensMapper, as it is.
      PATH_ENDS = {
        "color.primary-text" => "--nldesign-color-primary-text", "color.on-primary" => "--nldesign-color-primary-text",
        "color.primary-hover" => "--nldesign-color-primary-hover", "color.primary-light" => "--nldesign-color-primary-light",
        "color.primary" => "--nldesign-color-primary", "brand.primary" => "--nldesign-color-primary",
        "color.background" => "--nldesign-color-background", "color.text" => "--nldesign-color-text",
        "fontfamily.base" => "--nldesign-font-family", "typography.font-family" => "--nldesign-font-family",
        "border-radius.base" => "--nldesign-border-radius", "dimension.border-radius" => "--nldesign-border-radius"
      }.freeze

      # The types of Tokens Studio per kind of role. "borderRadius" and "fontFamilies" are Tokens Studio's own.
      STUDIO_TYPES = { color: "color", length: "borderRadius", font_family: "fontFamilies" }.freeze
      # The same for the kinds of the vocabulary. A kind Tokens Studio has no type for is "other", CSS text.
      STUDIO_VOCABULARY_TYPES = { color: "color", length: "dimension", size: "dimension", font_family: "fontFamilies",
                                  font_weight: "fontWeights", number: "number" }.freeze
      LIGHT_SET = "thematiq/light"
      DARK_SET = "thematiq/dark"

      CSS_NAME = /\A--[a-z0-9]+(?:-[a-z0-9]+)*\z/
      FULL_HEX = /\A#(\h{6})(\h{2})?\z/

      module_function

      def format(value)
        FORMATS.include?(value.to_s) ? value.to_s : nil
      end

      def file_name(token_set, format)
        base = "thematiq-#{token_set.id.gsub(/[^A-Za-z0-9_-]/, '-')}"
        format == "dtcg" ? "#{base}.tokens.json" : "#{base}.tokens-studio.json"
      end

      def export(token_set, format: "dtcg")
        document = format == "dtcg" ? dtcg(token_set) : studio(token_set, legacy: format == "tokens-studio-legacy")
        "#{JSON.pretty_generate(document)}\n"
      end

      # thematiq's DesignTokensWriter#pathOf.
      def path_of(css_name)
        css_name.sub(/\A-+/, "").split("-", 3).reject(&:empty?)
      end

      # --- W3C Design Tokens ---

      def dtcg(token_set)
        document = { "$description" => token_set.name }
        css_only = {}
        named_values(token_set).each do |name, kind, value|
          token = dtcg_token(kind, value)
          next css_only[name] = value unless token

          token["$extensions"] = { EXTENSION => { "cssVariable" => name } }.merge(token.delete(:own) || {})
          place(document, path_of(name), token)
        end
        own = { "generator" => "openproject-thematiq #{OpenProject::Thematiq::VERSION}", "format" => 1 }
        own["dark"] = token_set.dark_tokens.dup if token_set.dark?
        document["$extensions"] = { EXTENSION => { "setId" => token_set.id, "cssOnly" => css_only }, PLUGIN_EXTENSION => own }
        document
      end

      # [CSS name, kind, value] for every value of a set: the roles, then the vocabulary under thematiq's own names.
      def named_values(token_set)
        token_set.tokens.map { |role, value| [WRITE_NAMES.fetch(role), Tokens::TokenSet::ALL_KINDS.fetch(role), value] } +
          token_set.vocabulary.map { |key, value| [Tokens::Vocabulary.css_name(key), Tokens::Vocabulary.kind(key), value] }
      end

      # One value as a typed token, or nil when the format has no type for the value. Such a value goes into
      # thematiq's "cssOnly" list, which both sides read back.
      def dtcg_token(kind, value)
        case kind
        when :color then color_token(value)
        when :length, :size then length_token(value)
        when :font_family then font_token(value)
        when :font_weight then value.match?(/\A\d+\z/) ? { "$type" => "fontWeight", "$value" => value.to_i } : nil
        when :number then (number = exact_number(value)) ? { "$type" => "number", "$value" => number } : nil
        when :duration then duration_token(value)
        end
      end

      def duration_token(value)
        match = /\A(\d+(?:\.\d+)?)(ms|s)\z/.match(value)
        number = match && exact_number(match[1])
        number ? { "$type" => "duration", "$value" => { "value" => number, "unit" => match[2] } } : nil
      end

      # A colour object. A value that is not a six or eight digit hex is also kept as written, in the plugin's
      # own extension, so a file that comes back unchanged gives the same text.
      def color_token(value)
        object = color_object(value)
        return nil unless object

        token = { "$type" => "color", "$value" => object }
        token[:own] = { PLUGIN_EXTENSION => { "css" => value } } unless FULL_HEX.match?(value)
        token
      end

      def color_object(value)
        channels = Contrast.rgba(value) || eight_digit(value)
        return nil unless channels

        red, green, blue, alpha = channels
        object = { "colorSpace" => "srgb", "components" => [red, green, blue].map { |channel| (channel / 255.0).round(4) },
                   "hex" => Kernel.format("#%02x%02x%02x", red.round, green.round, blue.round) }
        object["alpha"] = alpha.round(3) if alpha < 1.0
        object
      end

      def eight_digit(value)
        case value
        when /\A#(\h\h)(\h\h)(\h\h)(\h\h)\z/ then [$1, $2, $3].map { |pair| pair.hex.to_f } + [$4.hex / 255.0]
        when /\A#(\h)(\h)(\h)(\h)\z/ then [$1, $2, $3].map { |digit| (digit * 2).hex.to_f } + [(($4 * 2).hex / 255.0)]
        end
      end

      # thematiq types px and rem as a dimension, a bare 0 as a number, and leaves em and % as CSS only.
      def length_token(value)
        return { "$type" => "number", "$value" => 0 } if value == "0"

        match = /\A(\d+(?:\.\d+)?)(px|rem)\z/.match(value)
        number = match && exact_number(match[1])
        number ? { "$type" => "dimension", "$value" => { "value" => number, "unit" => match[2] } } : nil
      end

      def exact_number(text)
        return nil unless text.match?(/\A\d+(?:\.\d+)?\z/)

        number = text.include?(".") ? text.to_f : text.to_i
        number.to_s == text ? number : nil
      end

      # A list of families, when writing the list back gives the same text. Else CSS only, as in thematiq.
      def font_token(value)
        families = value.split(",").map { |family| family.strip.delete_prefix("'").delete_suffix("'") }
        font_stack(families) == value ? { "$type" => "fontFamily", "$value" => families } : nil
      end

      def font_stack(families)
        families.map { |family| family.include?(" ") ? "'#{family}'" : family }.join(", ")
      end

      def place(node, path, token)
        *groups, leaf = path
        groups.each { |segment| node = (node[segment] ||= {}) }
        node[leaf] = token
      end

      # --- Tokens Studio for Figma ---

      # One file: a token set per theme, "$themes" and "$metadata". Values are CSS text, so every value fits.
      # The dark set holds only the colours the design system has for the dark theme.
      def studio(token_set, legacy:)
        document = { LIGHT_SET => studio_set(token_set.tokens, legacy:, vocabulary: token_set.vocabulary) }
        themes = [{ "id" => "light", "name" => "Light", "group" => token_set.name, "selectedTokenSets" => { LIGHT_SET => "enabled" } }]
        order = [LIGHT_SET]
        if token_set.dark?
          document[DARK_SET] = studio_set(token_set.dark_tokens, legacy:)
          themes << { "id" => "dark", "name" => "Dark", "group" => token_set.name,
                      "selectedTokenSets" => { LIGHT_SET => "enabled", DARK_SET => "enabled" } }
          order << DARK_SET
        end
        document["$themes"] = themes
        document["$metadata"] = { "tokenSetOrder" => order }
        document
      end

      def studio_set(tokens, legacy:, vocabulary: {})
        value_key, type_key, description_key = legacy ? %w[value type description] : %w[$value $type $description]
        tree = tokens.each_with_object({}) do |(role, value), result|
          name = WRITE_NAMES.fetch(role)
          place(result, path_of(name), { value_key => value, type_key => STUDIO_TYPES.fetch(Tokens::TokenSet::ALL_KINDS.fetch(role)),
                                         description_key => "thematiq role #{role}",
                                         "$extensions" => { EXTENSION => { "cssVariable" => name } } })
        end
        vocabulary.each do |key, value|
          name = Tokens::Vocabulary.css_name(key)
          place(tree, path_of(name), { value_key => value, type_key => STUDIO_VOCABULARY_TYPES.fetch(Tokens::Vocabulary.kind(key), "other"),
                                       "$extensions" => { EXTENSION => { "cssVariable" => name } } })
        end
        tree
      end
    end
  end
end

require "open_project/thematiq/contrast"
require "open_project/thematiq/figma/reader"
