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
          # CreateDialog sends the create actions to core's create dialog: this controller answers
          # /projects/:id/work_packages/dialog/new with the dialog, saves, and redirects back on success.
          "app/controllers/work_packages/dialogs_controller.rb" =>
            "1067f09f6b88890710bbafa756ba5f7efed1e2fc15442e0b67b9505c50fdd27a",
          # The dialog's id, title and footer, and the form's id and fields, which the script and
          # stylesheets/shell/70-create-modal.css name.
          "app/components/work_packages/dialogs/create_dialog_component.html.erb" =>
            "8dab61203a263c1cfa982b6703e71317213e804c8649ee607eb3f56350a6f9df",
          "app/components/work_packages/dialogs/create_form_component.html.erb" =>
            "a4bf04e4779bf93fed8a69b614c8b3e49c845c7d0781ffbf815d8e6fdb95b718",
          "app/forms/work_packages/dialogs/create_form.rb" =>
            "d9150197884c933d48637ddf306d0ffe440b929c798a20ae030e52f5044c2a85",
          # CreateDialogFields prepends render_custom_fields, which core's form calls after the description,
          "app/forms/custom_fields/custom_field_rendering.rb" =>
            "72ce5cfb1c12d9cad3244903b8dce3ffcf4d347fe2c4d6233312c8ed39d70f8f",
          # adds its fields with core's form inputs (the work package and user autocompleters),
          "lib/primer/open_project/forms/dsl/input_methods.rb" =>
            "7ed07ed88e2ef1697d4deff1e116f6bc0e426e4a1b1fc810519ba4a073b418b5",
          "lib/primer/open_project/forms/autocompleter.rb" =>
            "a1cad1193919706e17f53586199f58dcbb3f4f1bac2e1e973214eab3edbca9fb",
          # and relies on core permitting parent, assignee, priority and the dates of a new work package.
          "app/models/permitted_params.rb" =>
            "ce96f03a2b2d57780424887ca2a3f8a9f82baf61ef697dabf635147bb22dae72",
          # How core itself fetches that dialog: a GET with the Turbo stream type, rendered with renderStreamMessage.
          "frontend/src/stimulus/controllers/async-dialog.controller.ts" =>
            "075bf2b2ffb5b75ba32533defcba1e85a5e8d8eed97fdb5e95d63122a6dcff65",
          # The create links it recognises: the quick add menu's /projects/:id/work_packages/new?type=,
          "lib/redmine/menu_manager/top_menu/quick_add_menu.rb" =>
            "69d5ca873112ea33454f47747defe233b3866d98ee7cac070dba48364c83fd6f",
          # the page's Create button, button.add-work-package,
          "frontend/src/app/features/work-packages/components/wp-buttons/wp-create-button/wp-create-button.html" =>
            "a218269fdbd7be0a67417332e3da6c34509dfdd028ef81ff9c6ca5960b7c298b",
          # and the list of types under it, links to .../create_new?type=.
          "frontend/src/app/shared/components/op-context-menu/handlers/op-types-context-menu.directive.ts" =>
            "9b614916f565f35335f398ef9fd3b0d2344991d93a316af856e4be8471032358",
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
            "d44bf6153135f83c807d2831b841def1e0a5c1728d32113e697fa715751fccf5",
          # Shell::Gantt reads the follower and the one it follows from the classes of core's dependency lines,
          # and hides those lines: they are drawn for rows of 40 px.
          "frontend/src/app/features/work-packages/components/wp-table/timeline/global-elements/wp-timeline-relations.directive.ts" =>
            "dd52210cd565e7dc2b6bf6549a087f6bea50fdf1cd630cbbf0f67b3765f4c4e8",
          "frontend/src/app/features/work-packages/components/wp-table/timeline/global-elements/timeline-relation-element.ts" =>
            "963f361527b3d040b6d3d588725e889e06a8912fbf4e4e56834a8737b05e450f",
          # The header rows it relabels, found by their top offset, and the zoom level on the header.
          "frontend/src/app/features/work-packages/components/wp-table/timeline/header/wp-timeline-header.directive.ts" =>
            "f31d936957885915764fb8f5c07b45fae28143b2143373c7526dc59c957772db",
          # The grid lines and the class of a non-working day.
          "frontend/src/app/features/work-packages/components/wp-table/timeline/grid/wp-timeline-grid.directive.ts" =>
            "1dd0e0a7e080f1925ac742e29093c3e3e649e019405789b77b9a6ab44b4ea8f7",
          # The left of the today line, which the dates under the header are read from.
          "frontend/src/app/features/work-packages/components/wp-table/timeline/global-elements/wp-timeline.today-line.ts" =>
            "82d7a32a8ef598da94e8fa875a969987e21393f83ee1ac0f5fdb9da67448931a",
          # The markup of a bar, its labels and a milestone.
          "frontend/src/app/features/work-packages/components/wp-table/timeline/cells/timeline-cell-renderer.ts" =>
            "5b89a9750e5fe72971eee330f06f4aafd6adde235317eb495bbd0b830406acb7",
          "frontend/src/app/features/work-packages/components/wp-table/timeline/cells/timeline-milestone-cell-renderer.ts" =>
            "a2a35d355a423e51fce875d0f9d25231bce99a23c474f5675e268181954b27a3",
          # The zoom list presses core's zoom buttons by their ids.
          "frontend/src/app/features/work-packages/components/wp-buttons/wp-timeline-toggle-button/wp-timeline-toggle-button.html" =>
            "d0747905731ece91ee77063763de11f56bcae900b3f783d1186cecff04115b6e",
          # Export PDF opens the entry "Export" of core's "More actions" menu.
          "frontend/src/app/shared/components/op-context-menu/handlers/op-settings-dropdown-menu.directive.ts" =>
            "7daf1b6d320d380084a41e0d8a81b586f04f383e0ab7c5d675fa596facd10f0c",
          # The chips are core's two default Gantt views.
          "modules/gantt/app/services/gantt/default_query_generator_service.rb" =>
            "fb8abe768c97a0719f2513d5b22e1e7069eff27d356c8f6ded7ae36bb1331e37",
          # The timeline cells and the containers the stylesheet and the lines are placed in.
          "frontend/src/global_styles/content/work_packages/timelines/_timelines.sass" =>
            "7c7c5185bf36be6d6ae8193812e5ab9908fe59311762135184d6acc1a482a589"
        }.freeze

        # The files each set of overrides leans on. One set can stay on while the other is off.
        PARTS = {
          create_dialog: [
            "app/controllers/work_packages/dialogs_controller.rb",
            "app/components/work_packages/dialogs/create_dialog_component.html.erb",
            "app/components/work_packages/dialogs/create_form_component.html.erb",
            "app/forms/work_packages/dialogs/create_form.rb",
            "app/forms/custom_fields/custom_field_rendering.rb",
            "lib/primer/open_project/forms/dsl/input_methods.rb",
            "lib/primer/open_project/forms/autocompleter.rb",
            "app/models/permitted_params.rb",
            "frontend/src/stimulus/controllers/async-dialog.controller.ts",
            "lib/redmine/menu_manager/top_menu/quick_add_menu.rb",
            "frontend/src/app/features/work-packages/components/wp-buttons/wp-create-button/wp-create-button.html",
            "frontend/src/app/shared/components/op-context-menu/handlers/op-types-context-menu.directive.ts"
          ],
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
          ],
          gantt: [
            "frontend/src/app/features/work-packages/components/wp-table/timeline/global-elements/wp-timeline-relations.directive.ts",
            "frontend/src/app/features/work-packages/components/wp-table/timeline/global-elements/timeline-relation-element.ts",
            "frontend/src/app/features/work-packages/components/wp-table/timeline/header/wp-timeline-header.directive.ts",
            "frontend/src/app/features/work-packages/components/wp-table/timeline/grid/wp-timeline-grid.directive.ts",
            "frontend/src/app/features/work-packages/components/wp-table/timeline/global-elements/wp-timeline.today-line.ts",
            "frontend/src/app/features/work-packages/components/wp-table/timeline/cells/timeline-cell-renderer.ts",
            "frontend/src/app/features/work-packages/components/wp-table/timeline/cells/timeline-milestone-cell-renderer.ts",
            "frontend/src/app/features/work-packages/components/wp-buttons/wp-timeline-toggle-button/wp-timeline-toggle-button.html",
            "frontend/src/app/shared/components/op-context-menu/handlers/op-settings-dropdown-menu.directive.ts",
            "modules/gantt/app/services/gantt/default_query_generator_service.rb",
            "frontend/src/global_styles/content/work_packages/timelines/_timelines.sass"
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
