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
          # The header markup that stylesheets/shell/10-top-bar.css styles.
          "app/views/layouts/base.html.erb" =>
            "94becc56b0209c7bd7093096b96c4920d048b70a1dc4e487ab4bf9c9f997ee66"
        }.freeze

        # Relative paths of the files that are missing or differ from the recorded checksum.
        def self.changed_files(core_root = default_core_root)
          FILES.reject do |path, checksum|
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
