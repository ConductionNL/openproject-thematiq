# frozen_string_literal: true

require "open_project/thematiq/tokens"
require "open_project/thematiq/catalogue"
require "open_project/thematiq/custom_draft"
require "open_project/thematiq/shell/nextcloud_apps"
require "open_project/thematiq/shell/app_row"

module OpenProject
  module Thematiq
    # What the plugin remembers: which design system is active.
    # It keeps that in OpenProject's settings, which live in the database, so every process shares it.
    # Nothing here reads the network. What comes back out of the settings is checked again.
    class Store
      SETTING = :plugin_openproject_thematiq

      # Reads and writes the plugin's settings hash. The tests pass a hash backed stand-in.
      class SettingsBackend
        def read
          value = Setting.public_send(SETTING)
          value.respond_to?(:to_h) ? value.to_h.deep_stringify_keys : {}
        end

        def write(data)
          Setting.public_send(:"#{SETTING}=", data)
        end
      end

      attr_reader :catalogue

      def initialize(backend: SettingsBackend.new, catalogue: Catalogue.bundled)
        @backend = backend
        @catalogue = catalogue
      end

      # The id of the chosen set. nil on a fresh install.
      def active_id
        id = data["active_id"]
        id.is_a?(String) ? id : nil
      end

      # What the pages are styled with: the active custom design system, else the chosen set of the
      # catalogue, else the default.
      def active_token_set
        custom_set(active_custom_id) || catalogue.find(active_id) || catalogue.default
      end

      # Makes a design system the active one: a set of the catalogue or a custom design system.
      # Returns the set, or nil when the id is unknown.
      def activate(id)
        if (token_set = custom_set(id))
          write("active_custom" => id, "use_custom" => false)
          return token_set
        end

        token_set = catalogue.find(id)
        return nil unless token_set

        write("active_id" => token_set.id, "active_custom" => nil, "use_custom" => false)
        token_set
      end

      # A design system by id: a custom one or one of the catalogue. nil for an unknown or empty id.
      def find_set(id)
        return nil unless id.is_a?(String) && !id.empty?

        custom_set(id) || catalogue.find(id)
      end

      # Every design system there is, custom ones first.
      def all_sets
        custom_drafts.map(&:token_set) + catalogue.sets
      end

      # --- scopes: what the instance allows projects, see docs/design/scopes.md ---
      #
      # The choices themselves are rows in the plugin's table (Thematiq::Scope). Here are the instance's rules:
      # whether projects may choose at all (off by default), and from which design systems.

      PROJECTS_MAY_CHOOSE_KEY = "projects_may_choose"
      PROJECT_CHOICES_KEY = "project_choices"

      def projects_may_choose?
        data[PROJECTS_MAY_CHOOSE_KEY] == true
      end

      # The ids an instance admin allowed projects to choose from. Empty means every design system.
      def project_choices
        stored = data[PROJECT_CHOICES_KEY]
        stored.is_a?(Array) ? stored.grep(String).select { |id| find_set(id) } : []
      end

      # What a project admin may pick from.
      def sets_for_projects
        allowed = project_choices
        allowed.empty? ? all_sets : all_sets.select { |token_set| allowed.include?(token_set.id) }
      end

      # Stores the rules. Only ids of design systems there are count. Returns false and stores nothing otherwise.
      def save_project_rules(allow:, choices:)
        ids = Array(choices).map(&:to_s).reject(&:empty?).uniq
        return false if ids.size > 200 || ids.any? { |id| find_set(id).nil? }

        write(PROJECTS_MAY_CHOOSE_KEY => allow == true, PROJECT_CHOICES_KEY => ids)
        true
      end

      # --- custom design systems: a base design system plus overrides, any number up to MAX_CUSTOMS ---

      MAX_CUSTOMS = 50

      # The id of the custom design system in use, or nil.
      def active_custom_id
        id = data["active_custom"]
        id = CustomDraft::ID if id.nil? && data["use_custom"] == true # the shape of the version with one custom set
        custom_definitions.key?(id) ? id : nil
      end

      def custom_active?
        !active_custom_id.nil?
      end

      # Every stored custom design system as a draft, by name. Each is checked again on the way out.
      # With a query, only those whose name or id matches it, the way the catalogue is searched.
      def custom_drafts(query = nil)
        custom_definitions.keys.filter_map { |id| custom_draft(id) }
                          .select { |draft| Catalogue.match?(query, draft.name, draft.id) }
                          .sort_by { |draft| [draft.name.downcase, draft.id] }
      end

      # One stored custom design system as a draft. nil when there is none with that id.
      def custom_draft(id = CustomDraft::ID)
        stored = custom_definitions[id]
        return nil unless stored.is_a?(Hash) && stored["overrides"].is_a?(Hash)

        base = catalogue.find(stored["based_on"]) || catalogue.default
        draft = CustomDraft.new(base:, name: stored["name"], overrides: stored["overrides"], id:, logo: stored["logo"],
                                dark: stored["dark"], vocabulary: stored["vocabulary"], dark_vocabulary: stored["dark_vocabulary"])
        draft.name ? draft : nil
      end

      def custom_set(id = CustomDraft::ID)
        id.is_a?(String) ? custom_draft(id)&.token_set : nil
      end

      # The id a new custom design system gets: the first one that is free.
      def next_custom_id
        taken = custom_definitions.keys
        ([CustomDraft::ID] + (2..MAX_CUSTOMS).map { |number| "#{CustomDraft::ID}-#{number}" }).find { |id| !taken.include?(id) }
      end

      # Stores a valid draft under its id. Returns false and stores nothing when the draft has errors,
      # or when it is a new one and the limit is reached.
      def save_custom(draft)
        definitions = custom_definitions
        return false unless draft.valid?
        return false if !definitions.key?(draft.id) && definitions.size >= MAX_CUSTOMS

        write("customs" => definitions.merge(draft.id => draft.definition), "custom" => nil)
        true
      end

      def delete_custom(id = CustomDraft::ID)
        changes = { "customs" => custom_definitions.except(id), "custom" => nil }
        changes.merge!("active_custom" => nil, "use_custom" => false) if active_custom_id == id
        write(changes)
      end

      # --- the Nextcloud address for the app switcher links ---
      #
      # The key and the check are the shell's: Shell::NEXTCLOUD_URL_SETTING, read by Shell.nextcloud_url
      # and checked by Shell::NextcloudApps.normalize. The plugin never opens this address. It only links to it.

      NEXTCLOUD_URL_KEY = "nextcloud_url"

      def nextcloud_url
        Shell::NextcloudApps.normalize(data[NEXTCLOUD_URL_KEY])
      end

      # Stores the address, or clears it when the value is empty. Returns false and stores nothing
      # when the value is not an http or https address.
      def save_nextcloud_url(value)
        text = value.to_s.strip
        normalized = Shell::NextcloudApps.normalize(text)
        return false if !text.empty? && (normalized.nil? || text.length > 500)

        write(NEXTCLOUD_URL_KEY => normalized)
        true
      end

      # --- the row of tiles in the top bar ---
      #
      # The key and the reading are the shell's: Shell::TOP_BAR_APPS_SETTING, read by Shell.top_bar_apps through
      # Shell::AppRow.wanted. Empty is the row of the design, "none" is no row, otherwise keys separated by commas.

      TOP_BAR_APPS_KEY = "top_bar_apps"

      # [mode, keys]: "default" with the design's row, "none" with no keys, or "custom" with the stored keys.
      def top_bar_apps
        text = data[TOP_BAR_APPS_KEY].to_s.strip
        keys = Shell::AppRow.wanted(text)
        return ["none", []] if keys.empty?
        return ["default", Shell::AppRow::DEFAULT] if text.empty? || keys.equal?(Shell::AppRow::DEFAULT)

        ["custom", keys]
      end

      # Stores the choice. A custom row takes the picked keys in order, without empties and repeats, and needs at
      # least one. Only keys the field offers count, plus keys the setting already held. Returns false and
      # stores nothing when the choice cannot be used.
      def save_top_bar_apps(mode, keys)
        value = case mode
                when "default" then nil
                when "none" then Shell::AppRow::OFF
                when "custom" then custom_top_bar_value(keys)
                else return false
                end
        return false if value == false

        write(TOP_BAR_APPS_KEY => value)
        true
      end

      # The stored text of a custom row, or false when the picked keys cannot be used.
      def custom_top_bar_value(keys)
        allowed = Shell::AppRow::KNOWN | top_bar_apps.last
        picked = Array(keys).map { |key| key.to_s.strip }.reject(&:empty?).uniq
        return false if picked.empty? || picked.size > Shell::AppRow::MAX
        return false unless picked.all? { |key| Shell::AppRow::KEY.match?(key) && allowed.include?(key) }

        picked.join(", ")
      end

      # --- settings left by the version that fetched from thematiq ---

      LEGACY_KEYS = %w[base_url token_set fetched_at checked_at last_error last_error_detail].freeze

      # Removes what the plugin stored while it had a live link to thematiq: the address and the fetched
      # token set. Nothing reads those keys any more. Returns the keys it removed.
      def remove_legacy_settings
        current = data
        found = LEGACY_KEYS & current.keys
        @backend.write(current.except(*found)) if found.any?
        found
      end

      private

      # id => stored definition. Reads the shape of the version with one custom set as well:
      # that one set becomes "custom". Ids that do not look like a custom id are left out.
      def custom_definitions
        stored = data["customs"].is_a?(Hash) ? data["customs"] : {}
        stored = { CustomDraft::ID => data["custom"] }.merge(stored) if data["custom"].is_a?(Hash)
        stored.select { |id, definition| id.is_a?(String) && CustomDraft::ID_PATTERN.match?(id) && definition.is_a?(Hash) }
      end

      def data
        value = @backend.read
        value.is_a?(Hash) ? value : {}
      end

      def write(changes)
        @backend.write(data.merge(changes))
      end
    end
  end
end
