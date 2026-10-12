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
            "04bbbc96f85f3e37ce71eeafa4cd72f87da2da1098601b3a25e98f65eb1716e5"
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
