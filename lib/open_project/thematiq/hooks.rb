# frozen_string_literal: true

module OpenProject
  module Thematiq
    # Only layouts/base.html.erb calls this hook. Pages on the only_logo layout
    # (sign in, for example) do not get the stylesheet.
    class Hooks < OpenProject::Hook::ViewListener
      render_on :view_layouts_base_html_head, partial: "thematiq/hooks/head"

      # Core calls this hook at the top of the app switcher dialog, before its own module list
      # (lib/redmine/menu_manager/top_menu/module_menu.rb). The module list itself stays core's:
      # it comes from OpenProject's menu and permission helpers.
      render_on :module_menu_dialog_content_before, partial: "thematiq/shell/app_switcher_nextcloud"

      # The end of the body: the script of the two-layer project menu.
      render_on :view_layouts_base_body_bottom, partial: "thematiq/shell/body_bottom"
    end
  end
end
