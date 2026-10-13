# frozen_string_literal: true

require "open_project/thematiq/assets"
require "open_project/thematiq/contrast"

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
        # OpenProject marks its logo with this class in the light high contrast theme, where the bar is its own
        # pale grey (#eff2f5) and not the primary colour. The plugin's colours give way there.
        HIGH_CONTRAST_CLASS = "op-logo--link_high_contrast"
        BAR_SELECTOR = "#{SELECTOR}:not(.#{HIGH_CONTRAST_CLASS})".freeze
        HIGH_CONTRAST_SELECTOR = "#{SELECTOR}.#{HIGH_CONTRAST_CLASS}".freeze
        # The dark theme of the variable layer, where the bar takes the dark block's primary.
        DARK_SCOPE = 'body[data-color-mode="dark"][data-dark-theme="dark"]'

        # The address of the logo file, or nil. Assets picks it: a file the plugin serves itself under
        # /thematiq/logos/, the variant for dark backgrounds first because the bar is the primary colour,
        # and only for a design system whose logo the catalogue marks redistributable.
        def self.url(token_set, root: "")
          Assets.bundled.logo_url(token_set, root:)
        end

        # The variant follows the bar: the logo for dark backgrounds where white reads on the bar, the plain logo
        # where the bar is light (first full test, findings 5 and 12). Three bars: the primary colour, the dark
        # block's primary in the dark theme, and OpenProject's own pale grey in the light high contrast theme.
        def self.css(token_set, root: "")
          bar = pick(token_set, light: light?(token_set), root:)
          rules = [rule(bar, selector: BAR_SELECTOR)]
          if Contrast.dark_usable?(token_set) && token_set.dark_tokens["primary"]
            dark = pick(token_set, light: light?(token_set.dark_tokens), root:)
            rules << rule(dark, selector: "#{DARK_SCOPE} #{BAR_SELECTOR}") if dark != bar
          end
          # Only a plain logo goes on the pale bar. Without one, OpenProject's own high contrast logo stays.
          rules << rule(Assets.bundled.logo_variant_url(token_set, "logo", root:), selector: HIGH_CONTRAST_SELECTOR) if bar
          rules << rule(Assets.bundled.mobile_logo_url(token_set, root:), selector: MOBILE_SELECTOR)
          rules.reject(&:empty?).join("\n")
        end

        # White does not read on the bar's colour: the text there goes dark, and so must the logo.
        def self.light?(tokens)
          Contrast.on(tokens, "primary") != "#ffffff"
        end

        def self.pick(token_set, light:, root:)
          Assets.bundled.logo_url(token_set, root:, on_light: light)
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
