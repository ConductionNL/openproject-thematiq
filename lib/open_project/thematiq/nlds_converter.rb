# frozen_string_literal: true

require "json"
require "open_project/thematiq/tokens"
require "open_project/thematiq/contrast"
require "open_project/thematiq/css_tokens"

module OpenProject
  module Thematiq
    # Converts an NL Design System theme into a design system of the plugin: thematiq's converter
    # (scripts/convert-nlds-theme.mjs and js/lib/tokenConverter.js), ported to Ruby on the same mapping table.
    # data/mapping/nlds-to-nextcloud.json is thematiq's table as it is, vendored with its commit: what a theme token
    # becomes, in which order, and what is worked out when the theme has none.
    #
    # It reads a built theme CSS (custom properties in a class-scoped or :root block), a W3C Design Tokens JSON
    # document ($value) or a Style Dictionary tokens.json (value). What it takes over from thematiq and what it leaves:
    #   - the rules, the "never" list, the sources in their order with the brand prefix, and the fallbacks
    #     literal, derive (copy, onColor, darken, mix, alpha, rgbTriplet, literal template);
    #   - a "ramp" fallback (thematiq picks a grey from the theme's own palette) takes the table's default here;
    #   - a "manifest" fallback and the contrast repair are left out: the editor shows each contrast afterwards;
    #   - component tokens (--utrecht-*, --ams-*, --denhaag-*) are not carried: the plugin has no component bridge.
    # Every value passes the validator of its kind before it is kept. The report says what happened to each token.
    module NldsConverter
      MAPPING_PATH = File.expand_path("../../../data/mapping/nlds-to-nextcloud.json", __dir__)
      MAPPING_SOURCE = "thematiq development 6ab9ed15, scripts/mapping/nlds-to-nextcloud.json"
      MAX_DEPTH = 12
      PREFIX = /\A[a-z][a-z0-9-]{0,30}\z/

      Entry = Struct.new(:target, :value, :how, :source, keyword_init: true)
      Result = Struct.new(:tokens, :dark, :vocabulary, :dark_vocabulary, :report, :skipped, :prefix, :format, keyword_init: true)

      module_function

      def mapping
        @mapping ||= JSON.parse(File.read(MAPPING_PATH)).freeze
      end

      # text: the file. prefix: the theme's brand prefix ({p} in the table), or nil to guess it from the names.
      def convert(text, prefix: nil)
        format, declarations = declarations_of(text)
        prefix = prefix.to_s.strip.downcase
        prefix = guess_prefix(declarations) if prefix.empty?
        raise CssTokens::Refused, "prefix" unless prefix.nil? || PREFIX.match?(prefix)

        skipped = never(declarations)
        usable = declarations.except(*skipped.map(&:first))
        out = {}
        report = []
        mapping.fetch("rules").each do |rule|
          target = rule["target"]
          next unless target.start_with?("--nldesign-")

          entry = apply(rule, usable, out, prefix)
          next unless entry

          out[target] = entry.value
          report << entry
        end
        result = CssTokens.from_maps(out, {})
        Result.new(tokens: result.tokens, dark: {}, vocabulary: result.vocabulary, dark_vocabulary: {}, report:,
                   skipped: skipped.first(200), prefix:, format:)
      end

      # [format, { --name => value }] with references followed. Format: "css", "dtcg" or "style-dictionary".
      def declarations_of(text)
        raise CssTokens::Refused, "empty" if text.nil? || text.strip.empty?
        raise CssTokens::Refused, "too_large" if text.bytesize > CssTokens::MAX_BYTES

        stripped = text.strip
        if stripped.start_with?("{")
          document = begin
            JSON.parse(stripped, max_nesting: MAX_DEPTH + 2)
          rescue JSON::ParserError, EncodingError
            raise CssTokens::Refused, "not_css"
          end
          raise CssTokens::Refused, "not_css" unless document.is_a?(Hash)

          flat = {}
          dtcg = dtcg?(document, 0)
          flatten(document, [], flat, dtcg, 0)
          raise CssTokens::Refused, "nothing_usable" if flat.empty?

          return [dtcg ? "dtcg" : "style-dictionary", resolve_all(flat)]
        end

        light, _dark = CssTokens.declarations(text)
        ["css", resolve_all(light)]
      end

      def dtcg?(node, depth)
        return false unless node.is_a?(Hash) && depth <= MAX_DEPTH
        return true if node.key?("$value")

        node.values.any? { |child| dtcg?(child, depth + 1) }
      end

      # Nested tokens to --a-b-c names. A reference {a.b.c} becomes var(--a-b-c).
      def flatten(node, path, flat, dtcg, depth)
        raise CssTokens::Refused, "too_deep" if depth > MAX_DEPTH
        raise CssTokens::Refused, "too_many" if flat.size > CssTokens::MAX_DECLARATIONS

        key = dtcg ? "$value" : "value"
        if node.is_a?(Hash) && node.key?(key)
          value = node[key]
          return unless value.is_a?(String) || value.is_a?(Numeric)

          name = "--#{path.join('-')}"
          flat[name] = value.to_s.gsub(/\{([A-Za-z0-9_.-]{1,200})\}/) { "var(--#{Regexp.last_match(1).tr('.', '-')})" } if CssTokens::NAME.match?(name)
          return
        end
        return unless node.is_a?(Hash)

        node.each do |child_key, child|
          next if child_key.to_s.start_with?("$")

          part = child_key.to_s.downcase
          flatten(child, path + [part], flat, dtcg, depth + 1) if part.match?(/\A[a-z0-9_-]{1,60}\z/)
        end
      end

      def resolve_all(map)
        map.transform_values { |value| CssTokens.resolve(value, map) }.compact
      end

      # The most common first part of the names that are not a component prefix, like "zwolle" in --zwolle-color-primary.
      def guess_prefix(declarations)
        components = mapping.fetch("componentPrefixes")
        counts = Hash.new(0)
        declarations.each_key do |name|
          next if components.any? { |prefix| name.start_with?(prefix) } || name.start_with?("--nldesign-")

          first = name.delete_prefix("--").split("-").first
          counts[first] += 1 if first && PREFIX.match?(first)
        end
        counts.max_by { |_prefix, count| count }&.first
      end

      # [[name, reason]] for the tokens the table's "never" list leaves out.
      def never(declarations)
        rules = mapping.fetch("never")
        declarations.keys.filter_map do |name|
          rule = rules.find { |candidate| File.fnmatch(candidate["match"], name) }
          [name, rule["reason"]] if rule
        end
      end

      def apply(rule, declarations, out, prefix)
        sources = Array(rule["sources"]).map { |source| prefix ? source.gsub("{p}", prefix) : source }.reject { |source| source.include?("{p}") }
        # The first source the theme declares with a value the plugin can use at all. One that fails moves on.
        source = sources.find { |candidate| declarations.key?(candidate) && usable?(declarations[candidate]) }
        if source
          value = transform(rule["transform"], declarations[source], rule["args"] || {})
          return Entry.new(target: rule["target"], value:, how: "applied", source:) if value
        end

        fallback = rule["fallback"]
        return nil unless fallback.is_a?(Hash)

        value = case fallback["kind"]
                when "literal" then fallback["value"]
                when "ramp" then fallback["default"]
                when "derive"
                  base = out[fallback["from"]]
                  base && transform(fallback["transform"], base, fallback["args"] || {})
                end
        value ? Entry.new(target: rule["target"], value:, how: "fallback-#{fallback['kind']}", source: fallback["from"]) : nil
      end

      KINDS = %i[color length font_family number size duration border filter font_weight rgb_triplet text_transform].freeze

      def usable?(value)
        KINDS.any? { |kind| Tokens::Validator.respond_to?(kind) && Tokens::Validator.public_send(kind, value.to_s[0, 400]) }
      end

      def transform(kind, value, args)
        case kind
        when nil, "copy" then value
        when "literal" then args["template"].to_s.gsub("{value}", value.to_s)
        when "onColor" then Contrast.best_on(hex(value), [args["light"] || "#ffffff", args["dark"] || "#000000"])
        when "darken" then mix(value, "#000000", 1 - args.fetch("fraction", 0.1).to_f)
        when "mix" then mix(value, args["with"] || "#ffffff", args.fetch("weight", 0.5).to_f)
        when "alpha"
          color = hex(value)
          color && format("%s%02x", color, (args.fetch("fraction", 1).to_f * 255).round)
        when "rgbTriplet"
          channels = Contrast.rgba(hex(value).to_s)
          channels && channels.first(3).map(&:round).join(", ")
        end
      end

      # A colour as #rrggbb, or nil for one that cannot be read that way.
      def hex(value)
        color = Tokens::Validator.color(value.to_s)
        channels = color && Contrast.rgba(color)
        channels ? format("#%02x%02x%02x", *channels.first(3).map(&:round)) : nil
      end

      # weight of +value+, the rest +with+.
      def mix(value, with, weight)
        a = Contrast.rgba(hex(value).to_s)
        b = Contrast.rgba(hex(with).to_s)
        return nil unless a && b

        format("#%02x%02x%02x", *a.first(3).zip(b.first(3)).map { |x, y| ((x * weight) + (y * (1 - weight))).round })
      end
    end
  end
end
