# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Uploads
      # What the public endpoint answers with for one stored file. No Rails in here, so it is unit tested.
      #
      # Every answer carries the same locks, whatever the file is:
      #   - the content type the plugin decided on at upload, and "nosniff", so a browser does not guess another
      #   - a content security policy that allows no script, no network and no form, in a sandbox. It is what
      #     keeps an SVG file from running anything when somebody opens its address directly
      #   - a fixed file name, never the name the uploader gave
      # A replaced file gets a new address, so an address can be cached for a year.
      module Response
        POLICY = "default-src 'none'; style-src 'unsafe-inline'; img-src data:; sandbox"
        CACHE = "public, max-age=31536000, immutable"

        module_function

        def etag(record)
          %("#{record.sha256}")
        end

        def headers(record)
          {
            "Content-Type" => record.content_type,
            "Content-Disposition" => %(inline; filename="#{record.file_name}"),
            "Content-Security-Policy" => POLICY,
            "X-Content-Type-Options" => "nosniff",
            "Cross-Origin-Resource-Policy" => "same-origin",
            "Cache-Control" => CACHE,
            "ETag" => etag(record)
          }
        end

        # True when the browser already holds this file.
        def fresh?(record, if_none_match)
          return false unless if_none_match.is_a?(String)

          if_none_match.split(",").map { |tag| tag.strip.delete_prefix("W/") }.include?(etag(record))
        end
      end
    end
  end
end
