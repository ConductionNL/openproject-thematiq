# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "timeout"
require "uri"
require "open_project/thematiq/tokens/validator"

module OpenProject
  module Thematiq
    module Tokens
      # Reads the active token set from thematiq. Short timeouts, no redirects, a size limit.
      # It never raises: every outcome is a Result.
      class Client
        ENDPOINT_PATH = "/apps/thematiq/api/shell-tokens"
        MAX_BODY_BYTES = 256 * 1024
        ETAG_SAFE = /\A[\x21\x23-\x7E]{1,200}\z/

        # status: :ok, :not_modified or :error. error is a short code the admin page translates.
        Result = Struct.new(:status, :payload, :error, :detail, keyword_init: true) do
          def ok? = status == :ok
          def not_modified? = status == :not_modified
          def error? = status == :error
        end

        def self.endpoint_for(base_url)
          return nil unless Validator.absolute_http_url(base_url.to_s.strip)

          uri = URI.parse(base_url.to_s.strip)
          return nil if uri.query || uri.fragment

          uri.path = "#{uri.path.to_s.chomp('/')}#{ENDPOINT_PATH}"
          uri
        rescue URI::InvalidURIError
          nil
        end

        def initialize(open_timeout: 3, read_timeout: 5, deadline: 8)
          @open_timeout = open_timeout
          @read_timeout = read_timeout
          @deadline = deadline
        end

        def fetch(base_url, known_revision: nil)
          uri = self.class.endpoint_for(base_url)
          return failure("invalid_url") unless uri

          response = Timeout.timeout(@deadline) { request(uri, known_revision) }
          interpret(response)
        rescue Timeout::Error
          failure("timeout")
        rescue BodyTooLarge
          failure("too_large")
        rescue SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError, Net::ProtocolError, Net::HTTPBadResponse => e
          failure("unreachable", e.class.name)
        end

        private

        class BodyTooLarge < StandardError; end

        def request(uri, known_revision)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == "https"
          http.open_timeout = @open_timeout
          http.read_timeout = @read_timeout
          http.write_timeout = @read_timeout
          http.max_retries = 0

          get = Net::HTTP::Get.new(uri.request_uri)
          get["Accept"] = "application/json"
          get["User-Agent"] = "openproject-thematiq"
          get["If-None-Match"] = %("#{known_revision}") if known_revision.is_a?(String) && ETAG_SAFE.match?(known_revision)

          http.start do |connection|
            connection.request(get) do |response|
              body = +""
              response.read_body do |chunk|
                body << chunk
                raise BodyTooLarge if body.bytesize > MAX_BODY_BYTES
              end
              return [response.code.to_i, body]
            end
          end
        end

        def interpret((code, body))
          return Result.new(status: :not_modified) if code == 304
          return failure("http_status", code.to_s) unless code == 200

          payload = JSON.parse(body)
          payload.is_a?(Hash) ? Result.new(status: :ok, payload:) : failure("invalid_json")
        rescue JSON::ParserError
          failure("invalid_json")
        end

        def failure(error, detail = nil)
          Result.new(status: :error, error:, detail:)
        end
      end
    end
  end
end
