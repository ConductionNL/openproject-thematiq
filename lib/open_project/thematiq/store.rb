# frozen_string_literal: true

require "open_project/thematiq/tokens"
require "open_project/thematiq/catalogue"

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

      # What the pages are styled with: the chosen set, or the default when nothing usable is chosen.
      def active_token_set
        catalogue.find(active_id) || catalogue.default
      end

      # Makes a set of the catalogue the active one. Returns the set, or nil when the id is unknown.
      def activate(id)
        token_set = catalogue.find(id)
        return nil unless token_set

        write("active_id" => token_set.id)
        token_set
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
