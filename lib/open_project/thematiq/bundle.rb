# frozen_string_literal: true

require "json"
require "open_project/thematiq/tokens"
require "open_project/thematiq/custom_draft"
require "open_project/thematiq/scopes"
require "open_project/thematiq/store"

module OpenProject
  module Thematiq
    # The whole setup of the plugin as one document: the plugin's settings and the choices per project and module.
    # A version of the history is one bundle; the configuration file an administrator downloads is one too.
    #
    # Uploaded files do not travel in a bundle: they stay in the plugin's table, under the id of their design system.
    # A project is named by its identifier, so a bundle moves to another OpenProject.
    #
    # This module needs no Rails. Reading a bundle is reading hostile input: every value is checked again, the way
    # the store checks what it reads, and a bundle with one part that fails is refused whole.
    module Bundle
      FORMAT = "openproject-thematiq-bundle"
      VERSION = 1
      MAX_BYTES = 2 * 1024 * 1024
      MAX_SCOPES = 5000

      # The settings a bundle carries. Anything else in the plugin's settings is not part of the setup.
      SETTING_KEYS = %w[active_id active_custom customs projects_may_choose project_choices nextcloud_url top_bar_apps].freeze

      class Refused < StandardError
        attr_reader :code

        def initialize(code)
          @code = code
          super(code)
        end
      end

      # settings: the plugin's settings hash. scopes: rows with project_identifier, module_name, design_system_id.
      def self.build(settings:, scopes:, plugin_version: nil)
        { "format" => FORMAT, "version" => VERSION, "plugin_version" => plugin_version,
          "settings" => settings_part(settings),
          "scopes" => scopes.map do |row|
            { "project" => row[:project_identifier], "module" => row[:module_name].to_s, "design_system" => row[:design_system_id] }
          end.sort_by { |row| [row["project"].to_s, row["module"]] } }
      end

      def self.settings_part(settings)
        part = (settings.is_a?(Hash) ? settings : {}).slice(*SETTING_KEYS)
        # The shape of the version with one custom design system moves into "customs", as the store reads it.
        part["customs"] = { CustomDraft::ID => settings["custom"] }.merge(part["customs"] || {}) if settings.is_a?(Hash) && settings["custom"].is_a?(Hash)
        part.compact
      end

      # The JSON text of a bundle, for a download or a version.
      def self.dump(bundle)
        JSON.pretty_generate(bundle)
      end

      # A checked bundle. settings are ready to store, scopes name projects by identifier.
      Checked = Struct.new(:settings, :scopes, keyword_init: true)

      # Reads a bundle and checks every part of it. catalogue: the design systems that ship with the plugin.
      # project_exists: a callable that says whether a project identifier is known here.
      # Raises Refused with a short code when any part fails.
      def self.read(input, catalogue:, project_exists: ->(_identifier) { true })
        document = parse(input)
        raise Refused, "not_a_bundle" unless document.is_a?(Hash) && document["format"] == FORMAT
        raise Refused, "version" unless document["version"] == VERSION
        raise Refused, "unknown_keys" unless (document.keys - %w[format version plugin_version settings scopes]).empty?

        settings = document["settings"]
        raise Refused, "settings" unless settings.is_a?(Hash) && (settings.keys - SETTING_KEYS).empty?

        customs = check_customs(settings["customs"], catalogue)
        known = ->(id) { id.is_a?(String) && (customs.key?(id) || catalogue.find(id)) }
        check_settings(settings, known)
        scopes = check_scopes(document["scopes"], known, project_exists)
        Checked.new(settings: settings.merge("customs" => customs).compact, scopes:)
      end

      def self.parse(input)
        return input if input.is_a?(Hash)
        raise Refused, "empty" if input.nil? || input.to_s.strip.empty?
        raise Refused, "too_large" if input.bytesize > MAX_BYTES

        JSON.parse(input, max_nesting: 12)
      rescue JSON::ParserError, EncodingError
        raise Refused, "invalid_json"
      end

      # Every custom design system must read as the store reads it: a valid draft with a name.
      def self.check_customs(customs, catalogue)
        return {} if customs.nil?
        raise Refused, "customs" unless customs.is_a?(Hash) && customs.size <= Store::MAX_CUSTOMS

        customs.each do |id, definition|
          raise Refused, "customs" unless id.is_a?(String) && CustomDraft::ID_PATTERN.match?(id) && definition.is_a?(Hash)
          raise Refused, "customs" unless definition["overrides"].is_a?(Hash)

          base = catalogue.find(definition["based_on"]) || catalogue.default
          draft = CustomDraft.new(base:, name: definition["name"], overrides: definition["overrides"], id:, logo: definition["logo"],
                                  dark: definition["dark"], vocabulary: definition["vocabulary"],
                                  dark_vocabulary: definition["dark_vocabulary"], dark_errors: true)
          raise Refused, "custom_invalid" unless draft.valid?
        end
        customs.transform_values { |definition| definition.slice("name", "based_on", "overrides", "logo", "dark", "vocabulary", "dark_vocabulary") }
      end

      def self.check_settings(settings, known)
        raise Refused, "active" unless settings["active_id"].nil? || known.call(settings["active_id"])
        raise Refused, "active" unless settings["active_custom"].nil? || (settings["customs"] || {}).key?(settings["active_custom"])
        raise Refused, "projects" unless [nil, true, false].include?(settings["projects_may_choose"])

        choices = settings["project_choices"]
        raise Refused, "projects" unless choices.nil? || (choices.is_a?(Array) && choices.size <= 200 && choices.all? { |id| known.call(id) })

        url = settings["nextcloud_url"]
        raise Refused, "nextcloud_url" unless url.nil? || Shell::NextcloudApps.normalize(url) == url

        apps = settings["top_bar_apps"]
        raise Refused, "top_bar_apps" unless apps.nil? || (apps.is_a?(String) && apps.length <= 500)
      end

      def self.check_scopes(scopes, known, project_exists)
        return [] if scopes.nil?
        raise Refused, "scopes" unless scopes.is_a?(Array) && scopes.size <= MAX_SCOPES

        seen = {}
        scopes.map do |row|
          raise Refused, "scopes" unless row.is_a?(Hash) && (row.keys - %w[project module design_system]).empty?

          project = row["project"]
          module_name = row["module"].to_s
          raise Refused, "scopes" unless project.nil? || (project.is_a?(String) && project.length <= 100)
          raise Refused, "scopes" unless module_name.empty? || Scopes::MODULES.key?(module_name)
          raise Refused, "scopes" if project.nil? && module_name.empty?
          raise Refused, "scope_design_system" unless known.call(row["design_system"])
          raise Refused, "scope_project" unless project.nil? || project_exists.call(project)
          raise Refused, "scopes" if seen[[project, module_name]]

          seen[[project, module_name]] = true
          { project_identifier: project, module_name:, design_system_id: row["design_system"] }
        end
      end

      # What applying +after+ changes on top of +before+, both checked bundles or built ones, as [code, details].
      # names: a callable from a design system id to its name in either bundle.
      def self.changes(before, after)
        b = settings_of(before)
        a = settings_of(after)
        list = []
        active_before = b["active_custom"] || b["active_id"]
        active_after = a["active_custom"] || a["active_id"]
        list << ["active", { from: active_before, to: active_after }] if active_before != active_after

        customs_before = b["customs"] || {}
        customs_after = a["customs"] || {}
        (customs_after.keys - customs_before.keys).sort.each { |id| list << ["custom_added", { id:, name: customs_after[id]["name"] }] }
        (customs_before.keys - customs_after.keys).sort.each { |id| list << ["custom_removed", { id:, name: customs_before[id]["name"] }] }
        (customs_after.keys & customs_before.keys).sort.each do |id|
          list << ["custom_changed", { id:, name: customs_after[id]["name"] }] if customs_after[id] != customs_before[id]
        end

        list << ["projects_may_choose", { to: a["projects_may_choose"] == true }] if (b["projects_may_choose"] == true) != (a["projects_may_choose"] == true)
        list << ["project_choices", {}] if Array(b["project_choices"]).sort != Array(a["project_choices"]).sort
        list << ["nextcloud_url", { to: a["nextcloud_url"] }] if b["nextcloud_url"] != a["nextcloud_url"]
        list << ["top_bar_apps", {}] if b["top_bar_apps"].to_s != a["top_bar_apps"].to_s

        scopes_before = scopes_of(before)
        scopes_after = scopes_of(after)
        (scopes_after.keys | scopes_before.keys).sort_by { |key| key.map(&:to_s) }.each do |key|
          next if scopes_before[key] == scopes_after[key]

          list << ["scope", { project: key[0], module_name: key[1], from: scopes_before[key], to: scopes_after[key] }]
        end
        list
      end

      def self.settings_of(bundle)
        bundle.is_a?(Checked) ? bundle.settings : (bundle["settings"] || {})
      end

      def self.scopes_of(bundle)
        rows = if bundle.is_a?(Checked)
                 bundle.scopes
               else
                 (bundle["scopes"] || []).map { |row| { project_identifier: row["project"], module_name: row["module"].to_s, design_system_id: row["design_system"] } }
               end
        rows.to_h { |row| [[row[:project_identifier], row[:module_name]], row[:design_system_id]] }
      end
    end
  end
end
