# frozen_string_literal: true

require "json"

module OpenProject
  module Thematiq
    module Figma
      # Reads an uploaded Figma token set: a W3C Design Tokens file, or a Tokens Studio file or folder.
      #
      # The upload is hostile input. It has a size cap, a depth cap and a count cap. A reference that points
      # at itself is found and named. Every value goes through the validator of its role, so nothing but a
      # colour, a length or a font stack comes out. A token of any other type never reaches a role.
      #
      # It does not refuse a file for one bad token. It reads what it can and reports the rest: what was
      # imported, what was skipped and why. A file with nothing usable is refused.
      class Reader
        MAX_BYTES = 512 * 1024
        MAX_FILES = 40
        MAX_DEPTH = 12
        MAX_TOKENS = 5000
        MAX_HOPS = 16
        MAX_REPORTED = 200
        REFERENCE = /\A\{([^{}]{1,300})\}\z/

        # Every reason a token can be skipped for. The admin page has a sentence for each.
        REASONS = %w[not_mapped no_role duplicate missing_type wrong_type value_refused colour_space_not_supported
                     reference_missing reference_cycle reference_too_long expression_not_supported ref_not_supported
                     extends_not_supported name_not_allowed].freeze

        # code: a short word the admin page translates.
        class Refused < StandardError
          def code = message
        end

        # tokens and dark: role => validated value. vocabulary: vocabulary key => validated value.
        # imported: [{ role, path, value, theme }], with "vocabulary" => true for a vocabulary key.
        # skipped: [{ path, reason }], at most MAX_REPORTED, with the full number in skipped_count.
        Result = Struct.new(:name, :tokens, :dark, :vocabulary, :imported, :skipped, :skipped_count, :shape, keyword_init: true)

        # The types a role of each kind takes: the W3C names and the ones of Tokens Studio.
        TYPES = {
          color: %w[color],
          length: %w[dimension number borderRadius spacing sizing],
          font_family: %w[fontFamily fontFamilies]
        }.freeze

        # The types a vocabulary key of each kind takes. "other" is Tokens Studio's type for CSS text.
        LENGTH_TYPES = %w[dimension number borderRadius borderWidth spacing sizing fontSizes other].freeze
        VOCABULARY_TYPES = {
          color: %w[color], length: LENGTH_TYPES, size: LENGTH_TYPES, font_family: %w[fontFamily fontFamilies],
          font_weight: %w[fontWeight fontWeights number other], number: %w[number other], duration: %w[duration other]
        }.freeze
        TEXT_TYPES = %w[other].freeze

        # files: [[file name, text], ...]. One file, or the files of a Tokens Studio folder.
        def self.read(files)
          new(files).read
        end

        def initialize(files)
          @files = files.is_a?(Array) ? files : []
          @skipped = []
          @skipped_count = 0
          @count = 0
        end

        def read
          document = assemble
          studio = studio?(document)
          @own = own_file?(document, studio)
          light_tree, dark_tree, reference_only, dark_reference_only = studio ? studio_trees(document) : [document, nil, [], []]

          tokens, imported, vocabulary = roles(light_tree, reference_only:, loose: !studio, theme: "light", css_only: css_only(document))
          dark, dark_imported = dark_tree ? roles(dark_tree, reference_only: dark_reference_only, loose: false, theme: "dark", color_only: true) : [{}, []]
          own_dark(document).each do |role, value|
            next if dark.key?(role)

            dark[role] = value
            dark_imported << { "role" => role, "path" => "$extensions.#{PLUGIN_EXTENSION}.dark.#{role}", "value" => value, "theme" => "dark" }
          end
          raise Refused, "nothing_usable" if tokens.empty?

          Result.new(name: name_of(document), tokens:, dark:, vocabulary:, imported: imported + dark_imported, skipped: @skipped,
                     skipped_count: @skipped_count, shape: studio ? "tokens-studio" : "dtcg")
        end

        private

        # --- the files ---

        def assemble
          raise Refused, "empty" if @files.empty?
          raise Refused, "too_many_files" if @files.size > MAX_FILES
          raise Refused, "too_large" if @files.sum { |_name, text| text.to_s.bytesize } > MAX_BYTES

          parsed = @files.map { |name, text| [name.to_s, parse(text)] }
          return parsed.first.last if parsed.size == 1

          parsed.each_with_object({ "$metadata" => {} }) do |(name, content), document|
            key = File.basename(name).sub(/\.json\z/i, "").sub(/\.tokens\z/i, "")
            case key
            when "$themes" then document["$themes"] = content
            when "$metadata" then document["$metadata"] = content
            else document[key] = content
            end
          end
        end

        def parse(text)
          raise Refused, "empty" unless text.is_a?(String) && !text.strip.empty?

          text = text.dup.force_encoding(Encoding::UTF_8)
          raise Refused, "invalid_json" unless text.valid_encoding?

          JSON.parse(text.delete_prefix("﻿"), max_nesting: MAX_DEPTH + 6)
        rescue JSON::NestingError
          raise Refused, "too_deep"
        rescue JSON::ParserError
          raise Refused, "invalid_json"
        end

        # A Tokens Studio file says so with "$themes" or "$metadata". Its top level holds token sets.
        def studio?(document)
          raise Refused, "not_an_object" unless document.is_a?(Hash)

          document.key?("$themes") || document.key?("$metadata")
        end

        # --- Tokens Studio: which token sets make the light and the dark tree ---

        # Returns [light tree, dark tree or nil, the light paths that only resolve references, the same for dark].
        # The dark theme gives a role only where a token set of its own names it: a set it shares with the
        # light theme resolves references and gives nothing, so the dark block holds the dark colours alone.
        def studio_trees(document)
          sets = document.select { |key, value| !key.start_with?("$") && value.is_a?(Hash) }
          order = ordered(sets.keys, document.dig("$metadata", "tokenSetOrder"))
          themes = document["$themes"].is_a?(Array) ? document["$themes"].select { |theme| theme.is_a?(Hash) && theme["selectedTokenSets"].is_a?(Hash) } : []

          if themes.empty?
            dark_names = order.select { |name| dark_name?(name.split("/").last) }
            dark = dark_names.any? ? merge(sets, dark_names) : nil
            return [merge(sets, order - dark_names), dark, [], []]
          end

          dark_theme = themes.find { |theme| dark_name?(theme["name"]) || dark_name?(theme["id"]) }
          light_theme = (themes - [dark_theme]).first || dark_theme
          light = merge(sets, selected(light_theme, order, sets, %w[enabled source]))
          enabled = merge(sets, selected(light_theme, order, sets, %w[enabled]))
          reference_only = leaf_paths(light) - leaf_paths(enabled)
          return [light, nil, reference_only, []] unless dark_theme && dark_theme != light_theme

          dark = merge(sets, selected(dark_theme, order, sets, %w[enabled source]))
          own = merge(sets, selected(dark_theme, order, sets, %w[enabled]) - selected(light_theme, order, sets, %w[enabled source]))
          [light, dark, reference_only, leaf_paths(dark) - leaf_paths(own)]
        end

        def dark_name?(name)
          name.is_a?(String) && name.match?(/(?:\A|[^a-z])dark(?:\z|[^a-z])/i)
        end

        # The sets in the order of "$metadata.tokenSetOrder". Sets it does not list follow, by name.
        # A file from a folder upload has lost its folder, so an entry also matches by its last segment.
        def ordered(names, order)
          order = order.is_a?(Array) ? order.grep(String) : []
          listed = order.filter_map { |entry| names.find { |name| name == entry } || names.find { |name| name == entry.split("/").last } }
          listed.uniq + (names - listed).sort
        end

        def selected(theme, order, sets, statuses)
          chosen = theme["selectedTokenSets"].select { |_name, status| statuses.include?(status) }.keys
          order.select { |name| chosen.include?(name) || chosen.any? { |entry| entry.split("/").last == name } } & sets.keys
        end

        # Later sets replace earlier ones at the same path, as Tokens Studio does.
        def merge(sets, names)
          names.reduce({}) { |tree, name| replace_tree(tree, sets[name], 0) }
        end

        def replace_tree(base, over, depth)
          raise Refused, "too_deep" if depth > MAX_DEPTH

          over.each_with_object(base.dup) do |(key, node), result|
            both_groups = group?(node) && group?(result[key])
            result[key] = both_groups ? replace_tree(result[key], node, depth + 1) : node
          end
        end

        def group?(node)
          node.is_a?(Hash) && !token?(node)
        end

        # A token has "$value". In the older spelling of Tokens Studio it has "value" beside a "type",
        # or a "value" that is not itself a group.
        def token?(node)
          node.key?("$value") || (node.key?("value") && (node.key?("type") || !node["value"].is_a?(Hash)))
        end

        # --- from a tree to roles ---

        def leaf_paths(tree)
          leaves(tree, count: false).keys
        end

        # path => { value, type, css }. Walks with the depth cap and the count cap.
        def leaves(tree, count: true)
          result = {}
          walk = lambda do |node, path, inherited, depth|
            raise Refused, "too_deep" if depth > MAX_DEPTH
            next unless node.is_a?(Hash)

            if token?(node)
              raise Refused, "too_many_tokens" if count && (@count += 1) > MAX_TOKENS

              dollar = node.key?("$value")
              css = node.dig("$extensions", EXTENSION, "cssVariable") if node["$extensions"].is_a?(Hash) && node["$extensions"][EXTENSION].is_a?(Hash)
              own = node.dig("$extensions", PLUGIN_EXTENSION, "css") if node["$extensions"].is_a?(Hash) && node["$extensions"][PLUGIN_EXTENSION].is_a?(Hash)
              type = dollar ? node["$type"] : (node["type"] || node["$type"])
              result[path.join(".")] = { value: dollar ? node["$value"] : node["value"], type: type.is_a?(String) ? type : inherited,
                                         css: css.is_a?(String) && CSS_NAME.match?(css) ? css : nil, own: own.is_a?(String) ? own : nil,
                                         ref: node.key?("$ref") }
              next
            end

            skip(path.join("."), "extends_not_supported") if node.key?("$extends")
            type = node["$type"].is_a?(String) ? node["$type"] : inherited
            node.each do |key, child|
              next if key.start_with?("$")
              next skip((path + [key]).join("."), "name_not_allowed") if key.match?(/[{}.]/) || key.length > 200

              walk.call(child, path + [key], type, depth + 1)
            end
          end
          walk.call(tree, [], nil, 0)
          result
        end

        # Returns [role => value, the list of what was imported, vocabulary key => value].
        # loose: a reference may leave out the first segment of a path. That reads a Tokens Studio file
        # that has no "$themes" and no "$metadata", where the first segment is the name of a token set.
        def roles(tree, reference_only:, loose:, theme:, css_only: {}, color_only: false)
          all = leaves(tree)
          by_css = {}
          all.each do |path, leaf|
            next if reference_only.include?(path)
            next skip(path, "ref_not_supported") if leaf[:ref]

            resolved = resolve(path, all, loose)
            next skip(path, resolved) if resolved.is_a?(String)

            css = leaf[:css] || css_from_path(path)
            next skip(path, "not_mapped") unless css
            next skip(path, "duplicate") if by_css.key?(css)

            by_css[css] = { path:, value: resolved[:value], type: leaf[:type] || resolved[:type], own: leaf[:own] }
          end
          css_only.each { |css, value| by_css[css] ||= { path: "$extensions.#{EXTENSION}.cssOnly.#{css}", value:, type: :css } }

          tokens = {}
          imported = []
          used = []
          Tokens::TokenSet::ALL_KINDS.each do |role, kind|
            next if color_only && kind != :color

            read_names(role).each do |css|
              entry = by_css[css]
              next unless entry

              value = convert(kind, entry)
              if value.is_a?(Symbol)
                skip(entry[:path], value.to_s) unless used.include?(entry[:path])
                used << entry[:path]
                next
              end
              tokens[role] = value
              used << entry[:path]
              imported << { "role" => role, "path" => entry[:path], "value" => value, "theme" => theme }
              break
            end
          end
          vocabulary = color_only ? {} : vocabulary_of(by_css, imported, used)
          by_css.each_value { |entry| skip(entry[:path], "no_role") unless used.include?(entry[:path]) }
          [tokens, imported, vocabulary]
        end

        # A token under one of thematiq's vocabulary names becomes that key, through the validator of its kind.
        # A token can feed a role and a key at once: thematiq's error colour is also where the accent falls back to.
        def vocabulary_of(by_css, imported, used)
          vocabulary = {}
          by_css.each do |css, entry|
            key = Tokens::Vocabulary.key_of(css)
            next unless key

            value = convert(Tokens::Vocabulary.kind(key), entry, vocabulary: true)
            if value.is_a?(Symbol)
              skip(entry[:path], value.to_s) unless used.include?(entry[:path])
            else
              vocabulary[key] = value
              imported << { "role" => key, "path" => entry[:path], "value" => value, "theme" => "light", "vocabulary" => true }
            end
            used << entry[:path]
          end
          vocabulary
        end

        # The CSS names a role is read from. A file the plugin wrote names each role it has at the name it writes,
        # so only that name counts there. Without this a vocabulary token thematiq also reads a role from, such as
        # the content surface for the ground, would take the role's place on the way back, and a dark primary
        # would become a dark action colour the design system never had.
        def read_names(role)
          @own ? [WRITE_NAMES.fetch(role)] : READ_NAMES.fetch(role)
        end

        # The plugin's own W3C file has its extension at the root. Its own Tokens Studio file has its light token set.
        def own_file?(document, studio)
          return document.key?(LIGHT_SET) if studio

          document["$extensions"].is_a?(Hash) && document["$extensions"][PLUGIN_EXTENSION].is_a?(Hash)
        end

        # The CSS name of a path that has no extension: the table of path ends first, then a path that
        # holds thematiq's own names, "nldesign.color.primary" or "thematiq.shell.text", joined by dashes.
        def css_from_path(path)
          lower = path.downcase
          ending = PATH_ENDS.keys.select { |candidate| lower.end_with?(candidate) }.max_by(&:length)
          segments = path.split(".")
          start = segments.index("nldesign") || segments.each_cons(2).find_index(%w[thematiq shell])
          joined = start ? "--#{segments[start..].join('-')}" : nil
          known = joined && CSS_NAME.match?(joined) &&
                  (READ_NAMES.any? { |_role, names| names.include?(joined) } || Tokens::Vocabulary.key_of(joined))
          return joined if known

          ending ? PATH_ENDS[ending] : nil
        end

        # Follows references. Returns { value, type } or the reason as a String.
        def resolve(path, all, loose)
          seen = [path]
          leaf = all[path]
          MAX_HOPS.times do
            value = leaf[:value]
            # Only a value with a reference in it is followed. Any other text goes to the validator as it is.
            return { value:, type: leaf[:type] } unless value.is_a?(String) && value.match?(/\{[^{}]*\}/)

            match = REFERENCE.match(value.strip)
            return "expression_not_supported" unless match

            target = match[1].strip
            target = all.keys.find { |candidate| candidate.split(".", 2)[1] == target } if !all.key?(target) && loose
            return "reference_missing" unless target && all.key?(target)
            return "reference_cycle" if seen.include?(target)

            seen << target
            leaf = { value: all[target][:value], type: leaf[:type] || all[target][:type] }
          end
          "reference_too_long"
        end

        # The value of one role or vocabulary key, through the validator of its kind. A Symbol is the reason it was skipped.
        def convert(kind, entry, vocabulary: false)
          type = entry[:type]
          return :missing_type if type.nil?

          allowed = vocabulary ? VOCABULARY_TYPES.fetch(kind, TEXT_TYPES) : TYPES.fetch(kind)
          return :wrong_type unless type == :css || allowed.include?(type)

          text = case kind
                 when :color then color_text(entry)
                 when :length, :size then length_text(entry[:value])
                 when :font_family then font_text(entry[:value])
                 when :font_weight, :number then number_text(entry[:value])
                 when :duration then duration_text(entry[:value])
                 else entry[:value].is_a?(String) ? entry[:value] : :value_refused
                 end
          return text if text.is_a?(Symbol)

          text.is_a?(String) && text.length <= 400 ? (Tokens::Validator.public_send(kind, text) || :value_refused) : :value_refused
        end

        # A string as it is. A colour object in sRGB from its components. Any other colour space from its
        # "hex" member, when it has one. The text the plugin wrote beside it wins while it still means the same colour.
        def color_text(entry)
          value = entry[:value]
          return value if value.is_a?(String)
          return :value_refused unless value.is_a?(Hash)

          hex = srgb_hex(value) || fallback_hex(value)
          return :colour_space_not_supported unless hex

          own = entry[:own] && Tokens::Validator.color(entry[:own])
          own && Figma.color_object(own) && same_colour?(Figma.color_object(own), value) ? own : hex
        end

        def same_colour?(written, given)
          written["colorSpace"] == given["colorSpace"] && written["components"] == given["components"] &&
            (written["alpha"] || 1) == (given["alpha"] || 1)
        end

        def srgb_hex(value)
          components = value["components"]
          return nil unless value["colorSpace"] == "srgb" && components.is_a?(Array) && components.size == 3
          return nil unless components.all? { |component| component.is_a?(Numeric) && component.between?(0, 1) }

          with_alpha("##{components.map { |component| Kernel.format('%02x', (component * 255).round) }.join}", value["alpha"])
        end

        def fallback_hex(value)
          hex = value["hex"]
          hex.is_a?(String) && hex.match?(/\A#\h{6}\z/) ? with_alpha(hex.downcase, value["alpha"]) : nil
        end

        def with_alpha(hex, alpha)
          return hex if alpha.nil? || alpha == 1
          return nil unless alpha.is_a?(Numeric) && alpha.between?(0, 1)

          "#{hex}#{Kernel.format('%02x', (alpha * 255).round)}"
        end

        def length_text(value)
          case value
          when String then value
          when 0 then "0"
          when Hash
            number = value["value"]
            return :value_refused unless number.is_a?(Numeric) && number.finite? && %w[px rem].include?(value["unit"])

            "#{number.is_a?(Float) && number == number.to_i ? number.to_i : number}#{value['unit']}"
          else :value_refused
          end
        end

        # A number as JSON gives it, or the text. 600 and "600" are the same weight.
        def number_text(value)
          case value
          when String then value
          when Integer then value.to_s
          when Float then value.finite? ? (value == value.to_i ? value.to_i.to_s : value.to_s) : :value_refused
          else :value_refused
          end
        end

        def duration_text(value)
          case value
          when String then value
          when Hash
            number = value["value"]
            return :value_refused unless number.is_a?(Numeric) && number.finite? && %w[ms s].include?(value["unit"])

            "#{number_text(number)}#{value['unit']}"
          else :value_refused
          end
        end

        def font_text(value)
          case value
          when String then value
          when Array
            value.size <= 20 && value.all? { |family| family.is_a?(String) && family.length <= 60 } ? Figma.font_stack(value) : :value_refused
          else :value_refused
          end
        end

        # --- what sits beside the tokens ---

        # thematiq's list of values the format has no type for: CSS name => text.
        def css_only(document)
          map = document.dig("$extensions", EXTENSION, "cssOnly") if document["$extensions"].is_a?(Hash) && document["$extensions"][EXTENSION].is_a?(Hash)
          return {} unless map.is_a?(Hash)

          map.first(MAX_TOKENS).select { |css, value| css.is_a?(String) && CSS_NAME.match?(css) && value.is_a?(String) }.to_h
        end

        # The dark colours the plugin's own W3C file carries. Each goes through the colour validator.
        def own_dark(document)
          dark = document.dig("$extensions", PLUGIN_EXTENSION, "dark") if document["$extensions"].is_a?(Hash) && document["$extensions"][PLUGIN_EXTENSION].is_a?(Hash)
          return {} unless dark.is_a?(Hash)

          Tokens::TokenSet::DARK_KEYS.each_with_object({}) do |role, result|
            value = dark[role].is_a?(String) && dark[role].length <= 400 ? Tokens::Validator.color(dark[role]) : nil
            if value then result[role] = value
            elsif dark.key?(role) then skip("$extensions.#{PLUGIN_EXTENSION}.dark.#{role}", "value_refused")
            end
          end
        end

        # The name the file gives: its description, or the group of its first theme. nil when it gives none.
        def name_of(document)
          themes = document["$themes"]
          group = themes.first["group"] if themes.is_a?(Array) && themes.first.is_a?(Hash)
          Tokens::Validator.label(document["$description"], max: 80) || Tokens::Validator.label(group, max: 80)
        end

        def skip(path, reason)
          @skipped_count += 1
          @skipped << { "path" => Tokens::Validator.label(path.to_s, max: 200) || "?", "reason" => reason } if @skipped.size < MAX_REPORTED
        end
      end
    end
  end
end
