# frozen_string_literal: true

module OpenProject
  module Thematiq
    # OpenProject has two places to add to the head:
    #
    #   view_layouts_base_html_meta  in the shared head partial, so in layouts/base and layouts/only_logo.
    #                                It comes before OpenProject's stylesheets.
    #   view_layouts_base_html_head  in layouts/base only. It comes after OpenProject's stylesheets.
    #
    # The first gets the variable layer in its "early" form, which does not rely on source order.
    # That is what styles the pages on only_logo: error pages, the external link warning and OAuth consent.
    # The second gets everything, as before. On a base page both are present and the later one decides.
    class Hooks < OpenProject::Hook::ViewListener
      render_on :view_layouts_base_html_meta, partial: "thematiq/hooks/meta"
      render_on :view_layouts_base_html_head, partial: "thematiq/hooks/head"

      # Core calls this hook at the top of the app switcher dialog, before its own module list
      # (lib/redmine/menu_manager/top_menu/module_menu.rb). The module list itself stays core's:
      # it comes from OpenProject's menu and permission helpers.
      render_on :module_menu_dialog_content_before, partial: "thematiq/shell/app_switcher_nextcloud"

      # The end of the body: the script of the two-layer project menu.
      render_on :view_layouts_base_body_bottom, partial: "thematiq/shell/body_bottom"

      # The sign-in page as Nextcloud draws it: the logo above the card and the lines around it. See Shell::SignIn.
      render_on :view_account_login_top, partial: "thematiq/shell/sign_in_top"
      render_on :view_account_login_bottom, partial: "thematiq/shell/sign_in_bottom"
    end
  end
end
