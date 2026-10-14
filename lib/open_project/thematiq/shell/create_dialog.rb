# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Shell
      # A new work package in a dialog, as the OpCreateWorkPackage board draws it, from every create action of a
      # project: "Create work package" in the project menu, the page's Create button and the work package types
      # in the quick add menu of the top bar.
      #
      # The dialog is OpenProject's own: WorkPackages::DialogsController#new answers
      # /projects/:project_id/work_packages/dialog/new with a Turbo stream that opens
      # WorkPackages::Dialogs::CreateDialogComponent, a Primer dialog around core's create form. Core already uses
      # it for "new child" and in Backlogs. So the type, the subject, the description, the required custom fields,
      # the permission check, the validation and the save are all core's. The plugin adds a script that sends the
      # create actions there instead of to the page or the split view, and a stylesheet in the board's sizes.
      #
      # The script is rendered at the end of every page while the guarded core files are those of OpenProject
      # 17.9.1. When one differs, it is not rendered and every create action opens core's page as before.
      # See docs/shell-structure.md, "Create work package as a dialog".
      module CreateDialog
        SCRIPT_PATH = File.expand_path("assets/create_dialog.js", __dir__)

        def self.installed?
          return @installed unless @installed.nil?

          @installed = CoreGuard.changed_files(part: :create_dialog).empty?
        end

        # Tests set this back.
        def self.reset!
          @installed = nil
        end

        def self.script
          @script ||= File.read(SCRIPT_PATH)
        end

        # Only a signed-in user has create actions.
        def self.render?(user)
          installed? && user.respond_to?(:logged?) && user.logged?
        end

        TEXT_KEYS = %w[title submit].freeze

        # What the script needs. The address of the dialog is core's route, with the root of a sub-directory install.
        def self.kit(root:, translate:)
          {
            root: root.to_s.chomp("/"),
            texts: TEXT_KEYS.to_h { |key| [key, translate.call("thematiq.shell.create_dialog.#{key}")] }
          }
        end
      end
    end
  end
end
