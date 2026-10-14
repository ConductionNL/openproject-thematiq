# frozen_string_literal: true

require "open_project/thematiq/tokens"
require "open_project/thematiq/catalogue"
require "open_project/thematiq/custom_draft"
require "open_project/thematiq/editor"
require "open_project/thematiq/contrast"
require "date"
require "time"
require "open_project/thematiq/custom_css"
require "open_project/thematiq/variables/generator"
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

      # The design system an operator names in the environment. It wins over the choice on the admin page,
      # so a deployment can set the house style as code (gov-config-as-code).
      ENVIRONMENT_KEY = "THEMATIQ_DESIGN_SYSTEM"

      def initialize(backend: SettingsBackend.new, catalogue: Catalogue.bundled, env: ENV)
        @backend = backend
        @catalogue = catalogue
        @env = env
      end

      # What the environment says, as it says it. nil when the variable is not set or empty.
      def environment_value
        value = @env[ENVIRONMENT_KEY].to_s.strip
        value.empty? ? nil : value[0, 64]
      end

      # The id of the environment's design system, when it names one there is. An unknown id is ignored, and the
      # health report says so.
      def environment_id
        value = environment_value
        value && find_set(value) ? value : nil
      end

      # The id of the chosen set. nil on a fresh install.
      def active_id
        id = data["active_id"]
        id.is_a?(String) ? id : nil
      end

      # What the pages are styled with: the active custom design system, else the chosen set of the
      # catalogue, else the default. A planned switch whose time has come is made first (see #due_switch).
      def active_token_set
        apply_due_switch
        (environment_id && find_set(environment_id)) || custom_set(active_custom_id) || catalogue.find(active_id) || catalogue.default
      end

      # --- a planned switch: a design system that becomes the one in use at a date and time ---
      #
      # No background job: the first page after the time makes the switch (app-scheduled-switch, adapted). So a
      # switch planned for midnight happens with the first visitor after midnight.

      MAX_SWITCHES = 20

      # Every planned switch, oldest first: { "set_id", "at" (Time, UTC), "name" }. One whose design system is gone is left out.
      def planned_switches
        stored = data["planned_switches"]
        return [] unless stored.is_a?(Array)

        stored.filter_map do |entry|
          next unless entry.is_a?(Hash)

          at = (Time.iso8601(entry["at"].to_s) rescue nil)
          token_set = at && find_set(entry["set_id"].to_s)
          { "set_id" => token_set.id, "at" => at.utc, "name" => token_set.name } if token_set
        end.sort_by { |entry| entry["at"] }
      end

      # Plans a switch. nil, or a short code why nothing was stored.
      def plan_switch(set_id:, at:, now: Time.now)
        return "unknown_set" unless find_set(set_id.to_s)

        time = at.is_a?(Time) ? at : (Time.iso8601(at.to_s) rescue nil)
        return "time" if time.nil? || time <= now

        current = raw_switches
        return "too_many" if current.size >= MAX_SWITCHES

        write("planned_switches" => current + [{ "set_id" => set_id.to_s, "at" => time.utc.iso8601 }])
        nil
      end

      def cancel_switch(index)
        current = raw_switches
        write("planned_switches" => current.reject.with_index { |_entry, position| position == index.to_i })
      end

      # The switch whose time has come, if any: made now, and taken off the list. Returns its design system or nil.
      # on_switch: called with the design system, for the history.
      def apply_due_switch(now: Time.now)
        due = planned_switches.select { |entry| entry["at"] <= now }
        return nil if due.empty?

        last = due.last
        remaining = raw_switches.reject do |entry|
          at = (Time.iso8601(entry["at"].to_s) rescue nil)
          at.nil? || at <= now
        end
        write("planned_switches" => remaining)
        token_set = activate(last["set_id"])
        self.class.on_switch&.call(token_set, self) if token_set
        token_set
      end

      class << self
        # The engine sets this to write a history row when a planned switch is made.
        attr_accessor :on_switch
      end

      # --- the footer with legal links: privacy statement, imprint, accessibility statement ---

      FOOTER_LINKS = %w[privacy imprint accessibility].freeze

      # kind => address, for the links that are set. Only http and https addresses, checked again on the way out.
      def footer_links
        stored = data["footer_links"]
        return {} unless stored.is_a?(Hash)

        FOOTER_LINKS.each_with_object({}) do |kind, result|
          address = Shell::NextcloudApps.normalize(stored[kind])
          result[kind] = address if address && stored[kind].to_s.length <= 500
        end
      end

      # Stores the three addresses; an empty one is removed. false: one is not an http or https address.
      def save_footer_links(given)
        given = given.respond_to?(:to_h) ? given.to_h : {}
        cleaned = {}
        FOOTER_LINKS.each do |kind|
          text = given[kind].to_s.strip
          next if text.empty?

          address = Shell::NextcloudApps.normalize(text)
          return false if address.nil? || text.length > 500

          cleaned[kind] = address
        end
        write("footer_links" => cleaned)
        true
      end

      # --- locks: a project's design system that its project admins cannot change ---

      def locked_projects
        stored = data["locked_projects"]
        stored.is_a?(Array) ? stored.grep(String).select { |identifier| identifier.match?(/\A[a-z0-9][a-z0-9_-]{0,99}\z/) } : []
      end

      def locked?(identifier)
        locked_projects.include?(identifier.to_s)
      end

      def lock_project(identifier, locked)
        identifier = identifier.to_s
        return false unless identifier.match?(/\A[a-z0-9][a-z0-9_-]{0,99}\z/)

        list = locked_projects - [identifier]
        list << identifier if locked
        write("locked_projects" => list)
        true
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
                                dark: stored["dark"], vocabulary: stored["vocabulary"], dark_vocabulary: stored["dark_vocabulary"],
                                lock_primary: stored["lock_primary"] == true)
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
        return ["default", Shell::AppRow::DEFAULT] if text.empty? || keys.equal?(Shell::AppRow::DEFAULT)
        return ["none", []] if keys.empty?

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

      # --- the environment marker: a label on every page, so nobody works in the wrong OpenProject ---

      ENVIRONMENT_LABEL_KEY = "THEMATIQ_ENVIRONMENT_LABEL"
      MARKER_LABEL = /\A[\p{L}\p{N}][\p{L}\p{N} ._-]{0,29}\z/
      MARKER_COLOUR = "#d1242f"

      # { "label" => ..., "colour" => ..., "text" => ..., "from_environment" => bool } or nil when there is none.
      # The environment variable wins over the admin page, like THEMATIQ_DESIGN_SYSTEM.
      def environment_marker
        from_env = @env[ENVIRONMENT_LABEL_KEY].to_s.strip
        label = MARKER_LABEL.match?(from_env) ? from_env : data["environment_label"]
        return nil unless label.is_a?(String) && MARKER_LABEL.match?(label)

        colour = Tokens::Validator.color(data["environment_colour"].to_s) || MARKER_COLOUR
        { "label" => label, "colour" => colour, "text" => Contrast.best_on(colour, ["#ffffff", "#1b1c1d"]),
          "from_environment" => MARKER_LABEL.match?(from_env) }
      end

      # Stores the label and its colour, or clears both when the label is empty. false: nothing stored.
      def save_environment_marker(label, colour)
        label = label.to_s.strip
        return write("environment_label" => nil, "environment_colour" => nil) || true if label.empty?

        colour = colour.to_s.strip.empty? ? MARKER_COLOUR : Tokens::Validator.color(colour.to_s[0, 100])
        return false unless MARKER_LABEL.match?(label) && colour

        write("environment_label" => label, "environment_colour" => colour)
        true
      end

      # --- deprecations: a token an organisation is moving away from, with a severity, a replacement and a date ---

      SEVERITIES = %w[info warning critical].freeze
      MAX_DEPRECATIONS = 200

      # Every stored deprecation, checked again on the way out. due: the removal date has passed. Nothing is
      # ever removed or changed because of a deprecation: it is a notice.
      def deprecations(today: Date.today)
        stored = data["deprecations"]
        return [] unless stored.is_a?(Hash)

        stored.filter_map do |key, entry|
          next unless entry.is_a?(Hash) && Editor::KINDS.key?(key) && SEVERITIES.include?(entry["severity"])

          removal = (Date.iso8601(entry["removal"].to_s) rescue nil)
          replacement = Editor::KINDS.key?(entry["replacement"]) ? entry["replacement"] : nil
          { "key" => key, "severity" => entry["severity"], "replacement" => replacement, "removal" => removal&.iso8601,
            "message" => Tokens::Validator.label(entry["message"], max: 200), "due" => !removal.nil? && removal < today }
        end.sort_by { |entry| entry["key"] }
      end

      # Stores one deprecation. Returns nil, or a short code that says why nothing was stored.
      def save_deprecation(key:, severity:, replacement: nil, removal: nil, message: nil, today: Date.today)
        key = key.to_s
        replacement = replacement.to_s.empty? ? nil : replacement.to_s
        return "unknown_key" unless Editor::KINDS.key?(key)
        return "severity" unless SEVERITIES.include?(severity.to_s)
        return "replacement" if replacement && (!Editor::KINDS.key?(replacement) || replacement == key)

        date = nil
        unless removal.to_s.strip.empty?
          date = (Date.iso8601(removal.to_s.strip) rescue nil)
          return "removal" if date.nil? || date < today
        end
        text = message.to_s.strip.empty? ? nil : Tokens::Validator.label(message, max: 200)
        return "message" if !message.to_s.strip.empty? && text.nil?

        current = data["deprecations"].is_a?(Hash) ? data["deprecations"] : {}
        return "too_many" if !current.key?(key) && current.size >= MAX_DEPRECATIONS

        write("deprecations" => current.merge(key => { "severity" => severity.to_s, "replacement" => replacement,
                                                        "removal" => date&.iso8601, "message" => text }.compact))
        nil
      end

      def delete_deprecation(key)
        current = data["deprecations"].is_a?(Hash) ? data["deprecations"] : {}
        write("deprecations" => current.except(key.to_s))
      end

      # --- the whole setup, for the history and the configuration file (Bundle) ---

      # The plugin's settings as they are stored.
      def settings_snapshot
        data
      end

      # Replaces the setup's part of the settings with a checked bundle's. Keys a bundle does not carry stay.
      def replace_setup(settings)
        kept = data.except(*Bundle::SETTING_KEYS, "custom", "use_custom")
        @backend.write(kept.merge(settings.slice(*Bundle::SETTING_KEYS)))
      end

      # --- own tokens: values an organisation adds, as --thematiq-org-<name>, for its own CSS and other plugins ---

      OWN_TOKEN_NAME = /\A[a-z][a-z0-9-]{0,40}\z/
      OWN_TOKEN_KINDS = %w[color length number font_family duration].freeze
      MAX_OWN_TOKENS = 100

      # Every own token, checked again: name, label, kind, value and an optional dark value.
      def own_tokens
        stored = data["own_tokens"]
        return [] unless stored.is_a?(Hash)

        stored.filter_map do |name, entry|
          next unless OWN_TOKEN_NAME.match?(name.to_s) && entry.is_a?(Hash) && OWN_TOKEN_KINDS.include?(entry["kind"])

          value = Tokens::Validator.public_send(entry["kind"], entry["value"].to_s[0, 400])
          next unless value

          dark = entry["kind"] == "color" && entry["dark"] ? Tokens::Validator.color(entry["dark"].to_s[0, 400]) : nil
          { "name" => name, "label" => Tokens::Validator.label(entry["label"], max: 80) || name, "kind" => entry["kind"],
            "value" => value, "dark" => dark, "css_name" => "--thematiq-org-#{name}" }
        end.sort_by { |token| token["name"] }
      end

      # Stores one own token. nil, or a short code that says why nothing was stored.
      def save_own_token(name:, label:, kind:, value:, dark: nil)
        name = name.to_s.strip
        return "name" unless OWN_TOKEN_NAME.match?(name)
        return "kind" unless OWN_TOKEN_KINDS.include?(kind.to_s)

        cleaned = Tokens::Validator.public_send(kind.to_s, value.to_s.strip[0, 400])
        return "value" unless cleaned

        dark_value = nil
        if kind.to_s == "color" && !dark.to_s.strip.empty?
          dark_value = Tokens::Validator.color(dark.to_s.strip[0, 400])
          return "dark" unless dark_value
        end
        text = label.to_s.strip.empty? ? name : Tokens::Validator.label(label, max: 80)
        return "label" unless text

        current = data["own_tokens"].is_a?(Hash) ? data["own_tokens"] : {}
        return "too_many" if !current.key?(name) && current.size >= MAX_OWN_TOKENS

        write("own_tokens" => current.merge(name => { "label" => text, "kind" => kind.to_s, "value" => cleaned, "dark" => dark_value }.compact))
        nil
      end

      def delete_own_token(name)
        current = data["own_tokens"].is_a?(Hash) ? data["own_tokens"] : {}
        write("own_tokens" => current.except(name.to_s))
      end

      # The CSS of the own tokens: :root, and the dark values in OpenProject's dark theme. nil when there are none.
      def own_tokens_css
        tokens = own_tokens
        return nil if tokens.empty?

        light = tokens.map { |token| "  #{token['css_name']}: #{token['value']};" }
        dark = tokens.select { |token| token["dark"] }.map { |token| "  #{token['css_name']}: #{token['dark']};" }
        css = ":root {\n#{light.join("\n")}\n}"
        css += "\n#{Variables::Generator::DARK_SCOPE} {\n#{dark.join("\n")}\n}" if dark.any?
        css
      end

      # --- the administrator's own CSS: off by default, checked by CustomCss, served last ---

      def custom_css_enabled?
        data["custom_css_enabled"] == true
      end

      # The stored CSS, checked again on the way out. Empty when it no longer passes.
      def custom_css
        result = CustomCss.check(data["custom_css"].to_s)
        result.ok? ? result.css : ""
      end

      # What the page gets: the CSS when it is on and not empty, else nil.
      def served_custom_css
        css = custom_css_enabled? ? custom_css : ""
        css.empty? ? nil : css
      end

      # Checks and stores. Returns the CustomCss::Result; nothing is stored when it has errors.
      def save_custom_css(enabled:, text:)
        result = CustomCss.check(text)
        write("custom_css_enabled" => enabled == true, "custom_css" => result.css) if result.ok?
        result
      end

      # The digest of the configuration file BootBundle applied last, so an unchanged file is not applied again.
      def bundle_file_digest
        value = data["bundle_file_digest"]
        value.is_a?(String) ? value : nil
      end

      def remember_bundle_file_digest(digest)
        write("bundle_file_digest" => digest)
      end

      def raw_switches
        data["planned_switches"].is_a?(Array) ? data["planned_switches"].select { |entry| entry.is_a?(Hash) } : []
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
