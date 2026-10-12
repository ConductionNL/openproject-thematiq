# frozen_string_literal: true

require "open_project/thematiq/tokens/token_set"
require "open_project/thematiq/tokens/client"

module OpenProject
  module Thematiq
    module Tokens
      # Fetches the token set and records the outcome in the store.
      # A failed fetch never removes the last good token set.
      class Refresher
        # status: :updated, :unchanged, :not_configured or :failed.
        Outcome = Struct.new(:status, :error, :detail, :token_set, keyword_init: true) do
          def success? = %i[updated unchanged].include?(status)
        end

        def initialize(store:, client: Client.new, clock: -> { Time.now.utc })
          @store = store
          @client = client
          @clock = clock
        end

        # force: fetch the full document even when the stored revision is still current.
        def call(force: false)
          base_url = @store.base_url
          return Outcome.new(status: :not_configured) if base_url.to_s.strip.empty?

          known = force ? nil : @store.token_set&.revision
          result = @client.fetch(base_url, known_revision: known)

          if result.not_modified? && @store.token_set
            @store.record_success(nil, at: now)
            Outcome.new(status: :unchanged, token_set: @store.token_set)
          elsif result.ok?
            store_payload(result.payload)
          else
            fail_with(result.error || "unexpected_not_modified", result.detail)
          end
        end

        # Reads the endpoint without storing anything. Used by "Check connection".
        def check(base_url)
          result = @client.fetch(base_url)
          return Outcome.new(status: :failed, error: result.error || "unexpected_not_modified", detail: result.detail) unless result.ok?

          Outcome.new(status: :unchanged, token_set: TokenSet.from_payload(result.payload))
        rescue TokenSet::InvalidPayload => e
          Outcome.new(status: :failed, error: "invalid_payload", detail: e.message)
        end

        private

        def store_payload(payload)
          token_set = TokenSet.from_payload(payload)
          @store.record_success(token_set, at: now)
          Outcome.new(status: :updated, token_set:)
        rescue TokenSet::InvalidPayload => e
          fail_with("invalid_payload", e.message)
        end

        def fail_with(error, detail)
          @store.record_failure(error, detail, at: now)
          Outcome.new(status: :failed, error:, detail:)
        end

        def now
          @clock.call
        end
      end
    end
  end
end
