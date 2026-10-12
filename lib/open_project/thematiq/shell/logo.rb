# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Shell
      # The logo of the active design system, as one CSS rule for OpenProject's own logo link.
      # Without a logo in the token set there is no rule, and OpenProject's logo stays.
      module Logo
        SELECTOR = ".op-app-header .op-logo .op-logo--link"

        # The bar is the primary colour, so the inverse logo comes first.
        def self.url(token_set)
          token_set.logo_inverse_url || token_set.logo_url
        end

        def self.css(token_set)
          url = url(token_set)
          return "" if url.nil?

          %(#{SELECTOR} { background-image: url("#{escape(url)}"); })
        end

        # The token validator only lets an absolute http or https address through. This keeps
        # such an address from ending the string, the rule or the style tag it is written into.
        def self.escape(url)
          url.to_s.gsub(/[^A-Za-z0-9\-._~:\/?#\[\]@!$&*+,;=%]/) { |char| char.bytes.map { |byte| format("%%%02X", byte) }.join }
        end
      end
    end
  end
end
