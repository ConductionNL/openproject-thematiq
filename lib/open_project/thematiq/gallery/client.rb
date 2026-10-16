# frozen_string_literal: true

require "open_project/thematiq/gallery"

module OpenProject
  module Thematiq
    module Gallery
      # The one place the plugin opens a connection, for a feature an administrator turned on: the gallery, or the pull
      # of the setup from one other instance (Federation). A GET of one https address with short timeouts, no redirects
      # followed, at most +max_bytes+ read.
      module Client
        MAX_BYTES = 5 * 1024 * 1024
        TIMEOUT = 5

        module_function

        def fetch(url, enabled:, max_bytes: MAX_BYTES, headers: {})
          raise Off unless enabled
          raise Refused, "url" unless Gallery.valid_url?(url)

          require "net/http"
          uri = URI.parse(url)
          body = +""
          Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT, ssl_timeout: TIMEOUT) do |http|
            http.request(Net::HTTP::Get.new(uri.request_uri, headers.merge("Accept" => "application/json"))) do |response|
              raise Refused, "status_#{response.code}" unless response.is_a?(Net::HTTPSuccess)

              response.read_body do |chunk|
                body << chunk
                raise Refused, "too_large" if body.bytesize > max_bytes
              end
            end
          end
          body
        rescue Refused, Off
          raise
        rescue StandardError => e
          raise Refused, "unreachable_#{e.class.name.split('::').last.downcase.gsub(/[^a-z]/, '')}"[0, 60]
        end
      end
    end
  end
end
