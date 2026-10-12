# frozen_string_literal: true

require "time"
require "open_project/thematiq/tokens"

module OpenProject
  module Thematiq
    # Keeps the base URL, the last good token set and the outcome of the last fetch
    # in the plugin's settings. Settings live in the database, so the web and worker
    # processes share them, and reading them costs no HTTP request.
    class Store
      SETTING = :plugin_openproject_thematiq

      def base_url
        data["base_url"].to_s
      end

      def base_url=(value)
        write("base_url" => value.to_s.strip)
      end

      # The stored token set, checked again by the validator on the way out. nil when there is none.
      def token_set
        payload = data["token_set"]
        return nil unless payload.is_a?(Hash)

        Tokens::TokenSet.from_payload(payload.deep_stringify_keys)
      rescue Tokens::TokenSet::InvalidPayload
        nil
      end

      # What the pages are styled with: the stored set, or the bundled one.
      def active_token_set
        (base_url.empty? ? nil : token_set) || Tokens::TokenSet.bundled
      end

      def fetched_at = time("fetched_at")
      def checked_at = time("checked_at")

      def last_error
        data["last_error"].presence
      end

      def last_error_detail
        data["last_error_detail"].presence
      end

      # token_set is nil when thematiq answered "not modified".
      def record_success(token_set, at:)
        changes = { "checked_at" => at.iso8601, "last_error" => nil, "last_error_detail" => nil }
        changes.merge!("token_set" => token_set.to_payload, "fetched_at" => at.iso8601) if token_set
        write(changes)
      end

      def record_failure(error, detail, at:)
        write("checked_at" => at.iso8601, "last_error" => error.to_s, "last_error_detail" => detail.to_s.first(200))
      end

      def forget_token_set
        write("token_set" => nil, "fetched_at" => nil, "checked_at" => nil, "last_error" => nil, "last_error_detail" => nil)
      end

      private

      def data
        value = Setting.public_send(SETTING)
        value.respond_to?(:to_h) ? value.to_h.stringify_keys : {}
      end

      def write(changes)
        Setting.public_send(:"#{SETTING}=", data.merge(changes))
      end

      def time(key)
        Time.iso8601(data[key].to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
