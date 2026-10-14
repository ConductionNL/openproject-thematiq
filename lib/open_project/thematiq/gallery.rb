# frozen_string_literal: true

require "uri"
require "open_project/thematiq/catalogue"

module OpenProject
  module Thematiq
    # A gallery of thematiq's design systems, and a notice when thematiq published a newer catalogue
    # (cat-marketplace, syn-freshness-check, -dismiss, -status). The plugin's one network feature: off until an
    # administrator turns it on, and then it only reads one address the administrator can see and change, over https.
    # The answer is hostile input: it is read by the catalogue's own loader, which checks every value.
    module Gallery
      DEFAULT_URL = "https://raw.githubusercontent.com/ConductionNL/thematiq/development/docs/reference/shell-catalogue.json"
      CHECK_EVERY = 24 * 60 * 60

      class Off < StandardError; end

      class Refused < StandardError
        attr_reader :code

        def initialize(code)
          @code = code
          super(code)
        end
      end

      module_function

      # Only https, a host name, no credentials, at most 500 characters.
      def valid_url?(text)
        uri = URI.parse(text.to_s)
        uri.is_a?(URI::HTTPS) && !uri.host.to_s.empty? && uri.userinfo.nil? && text.to_s.length <= 500
      rescue URI::InvalidURIError
        false
      end

      # The catalogue in an answer. Raises Refused when it is not one.
      def read(body)
        document = begin
          JSON.parse(body.to_s, max_nesting: 20)
        rescue JSON::ParserError
          raise Refused, "invalid_json"
        end
        catalogue = Catalogue.from_document(document)
        raise Refused, "not_a_catalogue" if catalogue.error || catalogue.sets.empty?

        catalogue
      end

      # The sets of the gallery that this plugin does not have, or has with other values.
      def new_or_changed(gallery, local)
        gallery.sets.select do |token_set|
          mine = local.find(token_set.id)
          mine.nil? || mine.tokens != token_set.tokens || mine.vocabulary != token_set.vocabulary
        end
      end

      def due?(last_checked_at, now: Time.now)
        last_checked_at.nil? || now.to_i - last_checked_at.to_i >= CHECK_EVERY
      end
    end
  end
end
