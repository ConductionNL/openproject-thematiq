# frozen_string_literal: true

require "open_project/thematiq/tokens"
require "open_project/thematiq/figma"

module OpenProject
  module Thematiq
    # A house style as a CSS file of design tokens, the way thematiq writes its token sets: custom properties in
    # :root, and the dark values in a block whose selector or media query says dark. Hostile input: the file is read
    # as declarations only, nothing of it is ever written out as it is, and every value passes the validator of its kind.
    #
    # References between tokens, var(--a) or var(--a, fallback), are followed to their value (at most 16 steps),
    # so a file written with aliases works. The stored design system holds the values.
    module CssTokens
      MAX_BYTES = 512 * 1024
      MAX_DECLARATIONS = 5000
      MAX_HOPS = 16
      NAME = /\A--[A-Za-z0-9_-]{1,120}\z/
      VAR = /\Avar\(\s*(--[A-Za-z0-9_-]{1,120})\s*(?:,\s*(.{1,200}))?\)\z/m

      class Refused < StandardError
        attr_reader :code

        def initialize(code)
          @code = code
          super(code)
        end
      end

      Result = Struct.new(:tokens, :dark, :vocabulary, :dark_vocabulary, :imported, :skipped, keyword_init: true)

      module_function

      # The custom properties of a file: [light, dark], each name => raw value, the last declaration winning.
      def declarations(text)
        raise Refused, "empty" if text.nil? || text.strip.empty?
        raise Refused, "too_large" if text.bytesize > MAX_BYTES

        text = text.dup.force_encoding(Encoding::UTF_8)
        raise Refused, "not_css" unless text.valid_encoding?

        light = {}
        dark = {}
        count = 0
        walk(text.gsub(%r{/\*.*?\*/}m, " "), false) do |name, value, is_dark|
          count += 1
          raise Refused, "too_many" if count > MAX_DECLARATIONS

          (is_dark ? dark : light)[name] = value
        end
        raise Refused, "nothing_usable" if light.empty? && dark.empty?

        [light, dark]
      end

      # Walks blocks: selector { body }. A block whose selector or enclosing media query names dark gives dark values.
      def walk(css, dark_context, &block)
        position = 0
        while (open = css.index("{", position))
          prelude = css[position...open].to_s.strip
          close = matching_close(css, open)
          raise Refused, "not_css" unless close

          body = css[(open + 1)...close]
          dark = dark_context || dark_prelude?(prelude)
          if prelude.start_with?("@media", "@supports", "@layer")
            walk(body, dark, &block)
          elsif !prelude.start_with?("@")
            body.split(";").each do |part|
              name, value = part.split(":", 2).map { |piece| piece.to_s.strip }
              yield name, value, dark if value && NAME.match?(name.to_s) && !value.empty?
            end
          end
          position = close + 1
        end
      end

      def matching_close(css, open)
        depth = 0
        (open...css.length).each do |index|
          case css[index]
          when "{" then depth += 1
          when "}"
            depth -= 1
            return index if depth.zero?
          end
        end
        nil
      end

      def dark_prelude?(prelude)
        prelude.match?(/dark/i)
      end

      # Follows var() references to a value. nil for a cycle, a missing name without fallback, or too many steps.
      def resolve(value, map, hops = 0)
        return nil if hops > MAX_HOPS

        match = VAR.match(value.to_s.strip)
        return value.to_s.strip unless match

        target = map[match[1]]
        return resolve(target, map, hops + 1) if target
        return resolve(match[2], map, hops + 1) if match[2]

        nil
      end

      # The design system a thematiq token file describes: roles by thematiq's names (Figma::READ_NAMES, first match
      # wins), the vocabulary by its --nldesign- names. A value that fails its kind is skipped and named.
      def read(text)
        light, dark = declarations(text)
        skipped = []
        imported = 0
        pick = lambda do |map, fallback_map|
          everything = fallback_map.merge(map)
          tokens = {}
          Tokens::TokenSet::ALL_KINDS.each do |role, kind|
            name = Figma::READ_NAMES.fetch(role).find { |candidate| map.key?(candidate) }
            next unless name

            value = resolve(map[name], everything)
            cleaned = value && Tokens::Validator.public_send(kind, value)
            cleaned ? (tokens[role] = cleaned) && (imported += 1) : skipped << [name, value.nil? ? "reference" : "invalid"]
          end
          vocabulary = {}
          Tokens::Vocabulary::KINDS.each do |key, kind|
            name = Tokens::Vocabulary.css_name(key)
            next unless map.key?(name)

            value = resolve(map[name], everything)
            cleaned = value && Tokens::Validator.public_send(kind, value)
            cleaned ? (vocabulary[key] = cleaned) && (imported += 1) : skipped << [name, value.nil? ? "reference" : "invalid"]
          end
          [tokens, vocabulary]
        end
        tokens, vocabulary = pick.call(light, {})
        dark_tokens, dark_vocabulary = pick.call(dark, light)
        dark_tokens = dark_tokens.select { |role, _| Tokens::TokenSet::DARK_KEYS.include?(role) }
        raise Refused, "nothing_usable" if imported.zero?

        known = Figma::READ_NAMES.values.flatten + Tokens::Vocabulary.keys.map { |key| Tokens::Vocabulary.css_name(key) }
        unknown = (light.keys + dark.keys).uniq - known
        Result.new(tokens:, dark: dark_tokens, vocabulary:, dark_vocabulary:, imported:,
                   skipped: skipped.first(200) + unknown.first(200).map { |name| [name, "unknown"] })
      end
    end
  end
end
