# frozen_string_literal: true

require "open_project/thematiq/tokens"
require "open_project/thematiq/catalogue"
require "open_project/thematiq/custom_draft"

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

      # What the pages are styled with: the custom set when it is in use, else the chosen set,
      # else the default.
      def active_token_set
        (custom_active? ? custom_set : nil) || catalogue.find(active_id) || catalogue.default
      end

      # Makes a design system the active one: a set of the catalogue, or the custom set.
      # Returns the set, or nil when the id is unknown.
      def activate(id)
        if id == CustomDraft::ID
          token_set = custom_set
          write("use_custom" => true) if token_set
          return token_set
        end

        token_set = catalogue.find(id)
        return nil unless token_set

        write("active_id" => token_set.id, "use_custom" => false)
        token_set
      end

      # --- the custom set: a base design system plus overrides ---

      def custom_active?
        data["use_custom"] == true && !custom_draft.nil?
      end

      # The stored custom set as a draft, checked again on the way out. nil when there is none.
      def custom_draft
        stored = data["custom"]
        return nil unless stored.is_a?(Hash) && stored["overrides"].is_a?(Hash)

        base = catalogue.find(stored["based_on"]) || catalogue.default
        draft = CustomDraft.new(base:, name: stored["name"], overrides: stored["overrides"])
        draft.name ? draft : nil
      end

      def custom_set
        custom_draft&.token_set
      end

      # Stores a valid draft. Returns false and stores nothing when the draft has errors.
      def save_custom(draft)
        return false unless draft.valid?

        write("custom" => draft.definition)
        true
      end

      def delete_custom
        write("custom" => nil, "use_custom" => false)
      end

      private

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
