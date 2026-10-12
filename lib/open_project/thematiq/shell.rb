# frozen_string_literal: true

require "open_project/thematiq/shell/core_guard"

module OpenProject
  module Thematiq
    # The shared top bar and the project menu. See docs/shell-structure.md for what each part uses and why.
    #
    #   Shell::CoreGuard      the core files the shell depends on, with their checksums
    #   Shell::TopBar         two small overrides of OpenProject's top menu helpers
    #   Shell::ProjectMenu    the overrides of the project menu helpers and the project switcher
    #   Shell::NextcloudApps  the Nextcloud column of the app switcher
    #   Shell::AppRow         which apps and modules the top bar shows as icons
    #   Shell::Logo           the logo of the active design system, as a CSS rule
    #
    # The view hooks are registered in OpenProject::Thematiq::Hooks.
    module Shell
      # The plugin setting that holds the Nextcloud address for the app switcher links.
      # It is one optional key in Setting.plugin_openproject_thematiq.
      NEXTCLOUD_URL_SETTING = "nextcloud_url"

      # The Nextcloud address for the app switcher links, or nil. When it is nil the app switcher
      # shows OpenProject's own modules and no Nextcloud column.
      def self.nextcloud_url
        settings = Setting.plugin_openproject_thematiq
        value = settings.respond_to?(:to_h) ? settings.to_h.stringify_keys[NEXTCLOUD_URL_SETTING] : nil
        NextcloudApps.normalize(value)
      end

      # The plugin setting that says which apps and modules show as icons in the top bar, in order:
      # "files, mail, calendar, work_packages, boards, gantt, meetings". It is one optional key in
      # Setting.plugin_openproject_thematiq. Empty gives the row of the design, "none" gives no row.
      TOP_BAR_APPS_SETTING = "top_bar_apps"

      # The wanted keys, see Shell::AppRow.
      def self.top_bar_apps
        settings = Setting.plugin_openproject_thematiq
        AppRow.wanted(settings.respond_to?(:to_h) ? settings.to_h.stringify_keys[TOP_BAR_APPS_SETTING] : nil)
      end

      # Called from the engine's to_prepare block.
      #
      # The hooks only add markup, so they always run. The helper overrides lean on
      # private core methods, so they are only installed when the core files are the ones
      # they were written against. On any other OpenProject version the core top bar renders
      # unchanged and the log names the files that moved.
      def self.install!
        require "open_project/thematiq/shell/nextcloud_apps"
        require "open_project/thematiq/shell/app_row"
        require "open_project/thematiq/shell/logo"
        require "open_project/thematiq/shell/top_bar"

        require "open_project/thematiq/shell/project_menu"

        { top_bar: TopBar, project_menu: ProjectMenu }.each do |part, overrides|
          changed = CoreGuard.changed_files(part:)
          next overrides.install! if changed.empty?

          Rails.logger.error(
            "[openproject-thematiq] The #{part.to_s.tr('_', ' ')} overrides are off. These core files differ from " \
            "OpenProject #{CoreGuard::CORE_VERSION}: #{changed.join(', ')}. " \
            "See docs/shell-structure.md, \"When an OpenProject upgrade breaks this\"."
          )
        end
      end
    end
  end
end
