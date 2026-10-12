# frozen_string_literal: true

require "open_project/thematiq/tokens"

module OpenProject
  module Thematiq
    # What the plugin keeps in OpenProject's settings. Settings live in the database,
    # so every process shares them. Nothing here reads the network.
    class Store
      SETTING = :plugin_openproject_thematiq

      # What the pages are styled with.
      def active_token_set
        Tokens::TokenSet.fallback
      end

      private

      def data
        value = Setting.public_send(SETTING)
        value.respond_to?(:to_h) ? value.to_h.stringify_keys : {}
      end

      def write(changes)
        Setting.public_send(:"#{SETTING}=", data.merge(changes))
      end
    end
  end
end
