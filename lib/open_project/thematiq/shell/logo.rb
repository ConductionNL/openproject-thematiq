# frozen_string_literal: true

require "open_project/thematiq/assets"

module OpenProject
  module Thematiq
    module Shell
      # The logo of the active design system, as one CSS rule for OpenProject's own logo link.
      # Without a logo in the token set there is no rule, and OpenProject's logo stays.
      module Logo
        SELECTOR = ".op-app-header .op-logo .op-logo--link"
        # Below 850 px OpenProject hides the wide logo and shows this element, its square mark.
        # It is another element, so an uploaded mobile logo needs this selector. Still one rule per element.
        MOBILE_SELECTOR = ".op-app-header .op-logo--icon.op-logo--link"

        # The address of the logo file, or nil. Assets picks it: a file the plugin serves itself under
        # /thematiq/logos/, the variant for dark backgrounds first because the bar is the primary colour,
        # and only for a design system whose logo the catalogue marks redistributable.
        def self.url(token_set, root: "")
          Assets.bundled.logo_url(token_set, root:)
        end

        def self.css(token_set, root: "")
          [rule(url(token_set, root:)),
           rule(Assets.bundled.mobile_logo_url(token_set, root:), selector: MOBILE_SELECTOR)].reject(&:empty?).join("\n")
        end

        # The rule for one address. No address, no rule: OpenProject's logo stays.
        def self.rule(url, selector: SELECTOR)
          return "" if url.nil?

          %(#{selector} { background-image: url("#{escape(url)}"); })
        end

        # Assets only gives a plain path of the plugin's own. This is a second lock: whatever the address is,
        # it cannot end the string, the rule or the style tag it is written into.
        def self.escape(url)
          url.to_s.gsub(/[^A-Za-z0-9\-._~:\/?#\[\]@!$&*+,;=%]/) { |char| char.bytes.map { |byte| format("%%%02X", byte) }.join }
        end
      end
    end
  end
end
