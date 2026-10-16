# frozen_string_literal: true

require "json"
require "rexml/document"
require "open_project/thematiq/version"
require "open_project/thematiq/icons"

module OpenProject
  module Thematiq
    # The icon pack of the active design system (ast-icon-pack), resolved as thematiq does it: an administrator's
    # choice first, else the packs the token set's design system names. OpenProject's own icons follow the first pack
    # in that list that maps them, through data/icon-packs.json. Only the frontend route draws them: see
    # docs/design/frontend-build-variant.md.
    module IconPacks
      DATA = File.expand_path("../../../data/icon-packs.json", __dir__)
      ICON_DIR = File.expand_path("../../../public/thematiq/icons", __dir__)
      # The administrator's choice: follow the design system, no pack at all, or one pack by name.
      FOLLOW = ""
      NONE = "none"
      VIEW_BOX = /\A0 0 (\d+(?:\.\d+)?) (\d+(?:\.\d+)?)\z/

      class Unusable < StandardError; end

      # packs: the ordered list of packs; source: :override, :design_system or :none;
      # design_system: the design system the packs come from; drawn_by: the pack OpenProject's icons are drawn with.
      Resolution = Struct.new(:packs, :source, :design_system, :drawn_by, keyword_init: true) do
        def active? = !drawn_by.nil?
      end

      module_function

      def data
        @data ||= begin
          document = JSON.parse(File.read(DATA))
          document.is_a?(Hash) ? document.freeze : {}
        rescue JSON::ParserError, SystemCallError
          {}
        end
      end

      def maps = data["maps"] || {}
      def design_systems = data["design_systems"] || {}
      def token_sets = data["token_sets"] || {}

      # A pack the administrator may choose: one the plugin ships and maps OpenProject's icons to.
      def choosable
        maps.keys.select { |pack| Icons.sets.key?(pack) }.sort
      end

      def valid_choice?(value)
        [FOLLOW, NONE].include?(value) || choosable.include?(value)
      end

      # set_id: the active token set. base_id: the catalogue set a custom design system is based on.
      def resolve(set_id, choice: FOLLOW, base_id: nil)
        return Resolution.new(packs: [], source: :override, design_system: nil, drawn_by: nil) if choice == NONE
        return Resolution.new(packs: [choice], source: :override, design_system: nil, drawn_by: choice) if choosable.include?(choice)

        design_system = token_sets[set_id.to_s] || token_sets[base_id.to_s]
        packs = Array(design_systems[design_system]).select { |pack| Icons.sets.key?(pack) }
        return Resolution.new(packs: [], source: :none, design_system:, drawn_by: nil) if packs.empty?

        Resolution.new(packs:, source: :design_system, design_system:, drawn_by: packs.find { |pack| maps.key?(pack) })
      end

      # How many of OpenProject's icons a pack draws.
      def mapped_count(pack)
        maps.fetch(pack, {}).size
      end

      # The file the frontend module reads: per octicon name, the size and paths of the pack's icon. Every icon must
      # be filled paths only, as an octicon is: the octicon component draws paths and nothing else.
      def build(pack)
        icons = maps.fetch(pack).sort.to_h do |octicon, name|
          [octicon, shape(File.join(ICON_DIR, pack, "#{name}.svg"), "#{pack}/#{name}")]
        end
        { "pack" => pack, "icons" => icons }
      end

      def shape(path, label)
        raise Unusable, "#{label}: no such file" unless File.file?(path)

        root = REXML::Document.new(File.read(path)).root
        size = VIEW_BOX.match(root.attributes["viewBox"].to_s)
        raise Unusable, "#{label}: the viewBox does not start at 0 0" unless size
        # The octicon component finds the drawing by its height as a whole number.
        raise Unusable, "#{label}: the height is not a whole number" unless size[2].to_f == size[2].to_f.round

        rule = nil
        paths = []
        root.each_recursive do |node|
          # A group without attributes changes nothing about what it holds.
          next if node.name == "g" && node.attributes.empty?
          raise Unusable, "#{label}: holds <#{node.name}>, only <path> fits an octicon" unless node.name == "path"
          raise Unusable, "#{label}: is drawn with a stroke" if node.attributes["stroke"] && node.attributes["stroke"] != "none"

          node_rule = node.attributes["fill-rule"] || "nonzero"
          raise Unusable, "#{label}: mixes fill rules" if rule && rule != node_rule

          rule = node_rule
          paths << node.attributes["d"].to_s
        end
        raise Unusable, "#{label}: has no path" if paths.empty? || paths.any?(&:empty?)

        { "width" => size[1].to_f, "height" => size[2].to_i, "paths" => paths, "fill_rule" => rule }
      end

      # The pack as the page carries it, built once per pack. nil for a pack without a map or with an icon that does
      # not fit: then OpenProject keeps its own icons, and the log says why.
      def payload(pack)
        @payloads ||= {}
        return @payloads[pack] if @payloads.key?(pack)

        @payloads[pack] = maps.key?(pack) ? JSON.generate(build(pack)) : nil
      rescue Unusable, REXML::ParseException => e
        warn_unusable(pack, e)
        @payloads[pack] = nil
      end

      def warn_unusable(pack, error)
        message = "[openproject-thematiq] The icon pack #{pack} is not drawn: #{error.message}"
        defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger ? Rails.logger.error(message) : warn(message)
      end

      # The TypeScript the frontend module imports: every octicon a pack maps, as the shared data object of
      # @openproject/octicons-angular. A name that package does not export fails the frontend build.
      def targets_source
        names = maps.values.flat_map(&:keys).uniq.sort
        imports = names.map { |name| "  #{data_constant(name)}," }
        entries = names.map { |name| "  '#{name}': #{data_constant(name)}," }
        <<~TS
          // Written by script/build-icon-packs.rb from data/icon-packs.json. Do not edit.
          import {
          #{imports.join("\n")}
          } from '@openproject/octicons-angular';
          import type { IconData } from './apply';

          export const ICON_TARGETS:Record<string, IconData> = {
          #{entries.join("\n")}
          };
        TS
      end

      def data_constant(name)
        parts = name.split("-")
        "#{parts.first}#{parts.drop(1).map(&:capitalize).join}IconData"
      end
    end
  end
end
