# frozen_string_literal: true

require "digest"

module OpenProject
  module Thematiq
    module Shell
      # The core files the shell depends on, with the SHA-256 of each in CORE_VERSION.
      #
      # This file has no dependency on Rails, so script/check-core.rb can load it on its own.
      # When OpenProject changes one of these files, the check fails and the helper overrides
      # switch themselves off. Read the new core file, adjust the shell, then update the checksum.
      module CoreGuard
        CORE_VERSION = "17.9.1"

        FILES = {
          # TopBar overrides top_menu_left_menu_items and render_logo.
          "lib/redmine/menu_manager/top_menu_helper.rb" =>
            "3e221f320def6117811289a99dc8afce9e9797b7c2dcc46c8b64d65ead23cb59",
          # TopBar overrides the private lateral_user_menu_button(dialog, avatar).
          "lib/redmine/menu_manager/top_menu/user_menu.rb" =>
            "c76c725288bbffc5488e313ae187be259244b0ca625e396e33d350fdd2883afa",
          # Calls the module_menu_dialog_content_before hook. The app switcher CSS styles its dialog.
          "lib/redmine/menu_manager/top_menu/module_menu.rb" =>
            "d7c21127e74d95c1ad1001822bb8679eacad384202a6236667d1005ee0525bf0",
          # The header and menu markup that the files in stylesheets/shell/ style.
          "app/views/layouts/base.html.erb" =>
            "94becc56b0209c7bd7093096b96c4920d048b70a1dc4e487ab4bf9c9f997ee66",
          # ProjectMenu overrides render_menu, render_menu_node, menu_node_options and badge_for,
          # and replaces the class "menu_root closed" in what render_menu returns.
          "lib/redmine/menu_manager/menu_helper.rb" =>
            "85b6e7c95cb5b1cfb2d64b1446aa6d32c37a099ffcc69eae32e4e0e33a3359d4",
          # ProjectMenu overrides render_projects_top_menu_node.
          "lib/redmine/menu_manager/top_menu/projects_menu.rb" =>
            "e317ce71f292c155beb091e889e7707e0e013d73e1cbb76f412e2c6e619fb83d",
          # ProjectMenu overrides trigger_label, which the template prints inside the button.
          "app/components/header/project_select_component.rb" =>
            "8fd803f931972c6fbec7bd9ac8d927d6bbd414b1e12aa4c44018a229dd13ca0f",
          "app/components/header/project_select_component.html.erb" =>
            "04bbbc96f85f3e37ce71eeafa4cd72f87da2da1098601b3a25e98f65eb1716e5",
          # The two-layer menu shows core's nested list in place. It leans on the classes this
          # controller toggles from the arrow button (open and closed, on the list and on the row),
          "frontend/src/stimulus/controllers/dynamic/menus/main.controller.ts" =>
            "f024c5a86bf083571199ed16b0ec4ba9485c3f036e85e7baf2a5cba98ceb7d36",
          # on the rules that hide and show rows in those two states,
          "frontend/src/global_styles/layout/_main_menu.sass" =>
            "503996781a59c04192dcfc1a2c3d9443c621ae82c220fd3ce5ce24a49340fa4c",
          # and on the markup and layout of the submenu core loads into a module's frame.
          "app/components/open_project/common/submenu_component.html.erb" =>
            "fc3e917aeacff24a9979e778460b307b694178a68d54777ca6ffdec5441dfa57",
          "app/components/open_project/common/submenu_component.sass" =>
            "ce4271bce0fe31b726cc2c71e2fbb2e5a9ab94f1f67059473fa1388a8e4242d0",
          # Home overrides HomescreenController#index and renders what this view renders, plus the grid.
          "app/controllers/homescreen_controller.rb" =>
            "62a0826b0aaadeddb366e0a9ef1b1c47667c12844f58f41b878b34ff6044ecc0",
          "app/views/homescreen/index.html.erb" =>
            "876348a61cafb44fb429c40daf3813829c83b76039f457169b6ecd4675369cc4",
          # Home hands this component the Home blocks without the welcome text.
          "app/components/homescreen/blocks_grid_component.rb" =>
            "6b1afc42528cea5790ca601da78baf4f929ee40b18dafa884e6a9f2bddd6886f",
          # The block named "welcome" and its condition.
          "config/initializers/homescreen.rb" =>
            "5b1ccfe25018e01d67e3d6349c59567141a5c88f38f0fc714e3dc1b7566bed2e",
          # Home overrides My::PageController#show with a redirect to Home.
          "modules/my_page/app/controllers/my/page_controller.rb" =>
            "717755d22d73894f5e6184f0dc61ac3ddd527d1285302e7009303b1438db098d",
          # Scopes read the module of a page from current_menu_item. When it moves, a module's design system stops
          # applying (the lookup rescues and the page keeps its project's or the instance's), and this check says why.
          "lib/redmine/menu_manager/menu_controller.rb" =>
            "d44bf6153135f83c807d2831b841def1e0a5c1728d32113e697fa715751fccf5"
        }.freeze

        # The files each set of overrides leans on. One set can stay on while the other is off.
        PARTS = {
          top_bar: [
            "lib/redmine/menu_manager/top_menu_helper.rb",
            "lib/redmine/menu_manager/top_menu/user_menu.rb",
            "lib/redmine/menu_manager/top_menu/module_menu.rb",
            "app/views/layouts/base.html.erb"
          ],
          project_menu: [
            "lib/redmine/menu_manager/menu_helper.rb",
            "lib/redmine/menu_manager/top_menu/projects_menu.rb",
            "app/components/header/project_select_component.rb",
            "app/components/header/project_select_component.html.erb",
            "app/views/layouts/base.html.erb",
            "frontend/src/stimulus/controllers/dynamic/menus/main.controller.ts",
            "frontend/src/global_styles/layout/_main_menu.sass",
            "app/components/open_project/common/submenu_component.html.erb",
            "app/components/open_project/common/submenu_component.sass"
          ],
          home: [
            "app/controllers/homescreen_controller.rb",
            "app/views/homescreen/index.html.erb",
            "app/components/homescreen/blocks_grid_component.rb",
            "config/initializers/homescreen.rb",
            "modules/my_page/app/controllers/my/page_controller.rb"
          ],
          scopes: [
            "lib/redmine/menu_manager/menu_controller.rb",
            "app/views/layouts/base.html.erb"
          ]
        }.freeze

        # Relative paths of the files that are missing or differ from the recorded checksum.
        def self.changed_files(core_root = default_core_root, part: nil)
          files = part ? FILES.slice(*PARTS.fetch(part)) : FILES
          files.reject do |path, checksum|
            full = File.join(core_root.to_s, path)
            File.file?(full) && Digest::SHA256.file(full).hexdigest == checksum
          end.keys
        end

        def self.default_core_root
          defined?(Rails) && Rails.respond_to?(:root) && Rails.root ? Rails.root : "/app"
        end
      end
    end
  end
end
