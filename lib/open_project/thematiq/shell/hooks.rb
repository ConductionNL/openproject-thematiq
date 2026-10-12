# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Shell
      # Core calls this hook at the top of the app switcher dialog, before its own module list
      # (lib/redmine/menu_manager/top_menu/module_menu.rb). The module list itself stays core's:
      # it comes from OpenProject's menu and permission helpers.
      class Hooks < OpenProject::Hook::ViewListener
        render_on :module_menu_dialog_content_before, partial: "thematiq/shell/app_switcher_nextcloud"
      end
    end
  end
end
