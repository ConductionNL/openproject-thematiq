# frozen_string_literal: true

require "openssl"
require "securerandom"
require "open_project/thematiq/gallery"

module OpenProject
  module Thematiq
    # The setup shared between two instances (gov-federated-share). Both sides are off until an administrator turns
    # them on, each on its own instance:
    #   - Serving: GET SERVE_PATH answers the configuration file (the export of the whole setup, Bundle) to a request
    #     that names the share key in KEY_HEADER. Read only. Off, it answers 404 as if it did not exist.
    #   - Pulling: one https address of another instance and its share key. A pull reads the file through the gallery's
    #     client (https only, short timeouts, no redirects, at most Bundle::MAX_BYTES) and hands it to the same
    #     preview and checks as a configuration file uploaded by hand. Nothing is applied before the admin confirms.
    module Federation
      SERVE_PATH = "/thematiq/api/v1/setup"
      KEY_HEADER = "X-Thematiq-Share-Key"
      KEY = /\A[A-Za-z0-9_-]{32,128}\z/

      module_function

      def generate_key
        SecureRandom.urlsafe_base64(32)
      end

      def valid_key?(value)
        value.is_a?(String) && KEY.match?(value)
      end

      def valid_url?(text)
        Gallery.valid_url?(text)
      end

      # True when the key sent matches the stored one, compared in constant time.
      def key_matches?(given, stored)
        return false unless valid_key?(given) && valid_key?(stored) && given.bytesize == stored.bytesize

        OpenSSL.fixed_length_secure_compare(given, stored)
      end

      # The configuration file of the other instance, as text. Raises Gallery::Off when pulling is off, and
      # Gallery::Refused with a short code when the address, the key or the answer is refused.
      def fetch(url, key:, enabled:, max_bytes:)
        raise Gallery::Off unless enabled
        raise Gallery::Refused, "key" unless valid_key?(key)

        require "open_project/thematiq/gallery/client"
        Gallery::Client.fetch(url, enabled:, max_bytes:, headers: { KEY_HEADER => key })
      end
    end
  end
end
