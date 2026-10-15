# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Shell
      # The sign-in page as Nextcloud Zuiddrecht draws it (werkplek/NcLogin): no top bar, the logo above a card on
      # the ground colour, the brand stripe on top of the card, a line under the heading that says who signs in here,
      # and a line under the card. Core's form stays as it is: the fields, the button, the links and every check.
      #
      # It needs no override. The two hooks of core's login view (view_account_login_top and _bottom) add the logo,
      # the lines and a small script; stylesheets/shell/70-sign-in.css hides the bar and lays the page out. Both only
      # reach the pages of the account controller: sign in, lost password, registration and activation.
      module SignIn
        SCRIPT_PATH = File.expand_path("assets/sign_in.js", __dir__)

        def self.script
          @script ||= File.read(SCRIPT_PATH)
        end

        # { logo:, watermark:, organisation: } for a token set. The organisation is named only for a design system
        # with an emblem, the mark of an organisation; OpenProject's own colour themes and the other sets name none.
        def self.view(token_set, root: "")
          emblem = Logo.emblem_url(token_set, root:)
          { logo: Assets.bundled.logo_url(token_set, root:, on_light: true),
            watermark: emblem,
            organisation: (token_set.name if emblem) }
        end
      end
    end
  end
end
