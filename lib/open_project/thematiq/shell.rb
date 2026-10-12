# frozen_string_literal: true

require "open_project/thematiq/shell/core_guard"

module OpenProject
  module Thematiq
    # The shared top bar. See docs/shell-structure.md for what each part uses and why.
    #
    #   Shell::CoreGuard      the core files the shell depends on, with their checksums
    #   Shell::TopBar         three small overrides of OpenProject's top menu helpers
    #   Shell::NextcloudApps  the Nextcloud column of the app switcher
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

      # Called from the engine's to_prepare block.
      #
      # The hooks only add markup, so they always run. The helper overrides lean on
      # private core methods, so they are only installed when the core files are the ones
      # they were written against. On any other OpenProject version the core top bar renders
      # unchanged and the log names the files that moved.
      def self.install!
        require "open_project/thematiq/shell/nextcloud_apps"
        require "open_project/thematiq/shell/logo"
        require "open_project/thematiq/shell/top_bar"

        changed = CoreGuard.changed_files
        if changed.empty?
          TopBar.install!
        else
          Rails.logger.error(
            "[openproject-thematiq] The top bar overrides are off. These core files differ from " \
            "OpenProject #{CoreGuard::CORE_VERSION}: #{changed.join(', ')}. " \
            "Check them against lib/open_project/thematiq/shell/top_bar.rb, then update core_guard.rb."
          )
        end
      end
    end
  end
end
