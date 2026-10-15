# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Shell
      # OpenProject builds its top bar in helper methods, not in a view, so a view override
      # cannot reach it and no hook renders inside the logo block or the account button.
      # These two overrides are the smallest change that puts the app row after the logo and the
      # name and role in the account button. Each one calls super and only adds to or reorders
      # what core returns.
      #
      # Written against OpenProject 17.9.1:
      #   lib/redmine/menu_manager/top_menu_helper.rb     (top_menu_left_menu_items, render_logo)
      #   lib/redmine/menu_manager/top_menu/module_menu.rb (more_top_menu_items, read only)
      #   lib/redmine/menu_manager/top_menu/user_menu.rb  (lateral_user_menu_button)
      # CoreGuard holds their checksums. Shell.install! skips this module when they differ.
      module TopBar
        def self.install!
          helper = ::Redmine::MenuManager::TopMenuHelper
          helper.prepend(self) unless helper.ancestors.include?(self)
        end

        # Core returns the app switcher first, then the logo. The design puts the logo first, then
        # the app switcher, as the dossiq bar draws it. An administrator can add a row of apps and modules
        # between the two (Tiles in the top bar); the design has none.
        # Moving the elements, not just their CSS order, keeps the focus order equal to what you see.
        def top_menu_left_menu_items
          switcher, *rest = super
          rest + [thematiq_app_row, switcher].compact
        end

        # The brand block of the dossiq bar: the design system's emblem, its name over the name of this
        # OpenProject, as one link home. A design system without an emblem shows its logo and the name of
        # OpenProject. Without a logo of its own the logo is OpenProject's, which already says the name, so the
        # name is kept for screen readers only. The logo itself is core's element with core's class, so the logo
        # rule of Shell::Logo and core's theme switcher keep working on it.
        def render_logo
          token_set = OpenProject::Thematiq.active_token_set
          emblem = Logo.emblem_url(token_set).present?
          named = emblem || Assets.bundled.logo_url(token_set).present?
          mode_class = "op-logo--link_high_contrast" if User.current.pref.light_high_contrast_theme?
          tag.div(class: ["op-logo", "thematiq-brand", ("thematiq-brand--has-emblem" if emblem)].compact) do
            link_to(configurable_home_url, class: "thematiq-brand--link", data: { test_selector: "thematiq-brand" }) do
              concat tag.span(class: ["op-logo--link", mode_class].compact, "aria-hidden": "true",
                              data: { auto_theme_switcher_target: "desktopLogo" })
              concat(tag.span(class: "thematiq-brand--text") do
                concat tag.span(token_set.name, class: "thematiq-brand--organisation") if emblem
                concat tag.strong(Setting.app_title, class: ["thematiq-brand--app", ("sr-only" unless named)].compact)
              end)
            end
          end
        rescue StandardError => e
          Rails.logger.error("[openproject-thematiq] The brand block fell back to core's logo: #{e.class}: #{e.message}")
          super
        end

        private

        # Core puts whatever it gets as `avatar` inside the account button. Passing the avatar
        # plus the name and role adds them to the button without copying the core method.
        # Core skips the content block when there is no avatar, and then nothing is added.
        def lateral_user_menu_button(dialog, avatar)
          return super unless User.current.logged? && avatar.present?

          super(dialog, safe_join([avatar, thematiq_account_label]))
        end

        # The row of apps and modules: links with an icon and a name. Everything in the row is also in
        # the app switcher, so nothing is lost when the row folds on a narrow screen.
        def thematiq_app_row
          entries = thematiq_app_row_entries
          return if entries.empty?

          tag.ul(class: "thematiq-app-row") do
            entries.each { |entry| concat tag.li(thematiq_app_row_item(entry)) }
          end
        end

        # Which entries, in which order: Shell::AppRow decides from the setting, from what this user
        # can open, and from the page. What a user can open is core's decision: the modules come from
        # core's own menu and permission helpers. A module the instance has no licence for stays in
        # the app switcher, where core marks it.
        def thematiq_app_row_entries
          all = thematiq_app_row_candidates
          current = AppRow.current_key(current_menu_item)
          current = nil unless all.key?(current)

          AppRow.pick(Shell.top_bar_apps, all.keys, current).map { |key| all.fetch(key).merge(current: key == current) }
        end

        def thematiq_app_row_candidates
          all = {}
          if (base = Shell.nextcloud_url)
            NextcloudApps::APPS.each do |app|
              all[app.key.to_s] = { label: t("thematiq.shell.app_switcher.apps.#{app.key}"),
                                    href: NextcloudApps.url_for(app, base), path: app.icon, external: true }
            end
          end

          mine, others = more_top_menu_items.reject(&:heading?).partition { |item| item.context == :my }
          (mine + others).reject(&:enterprise_feature_missing?).each do |item|
            all[item.name.to_s] ||= { label: item.caption, href: url_for(item.url),
                                      path: AppRow::ICONS[item.name.to_s], octicon: item.icon }
          end
          all
        end

        # The name is real text in the link. The stylesheet shows it under the icon on the current
        # tile and on hover and focus, and keeps it for screen readers otherwise.
        def thematiq_app_row_item(entry)
          options = { href: entry[:href], class: "thematiq-app-row--item" }
          options[:"aria-current"] = "page" if entry[:current]
          options[:"data-allow-external-link"] = "true" if entry[:external]

          tag.a(**options) do
            concat thematiq_app_row_icon(entry)
            concat tag.span(entry[:label].to_s, class: "thematiq-app-row--name")
          end
        end

        # An outline icon of the design where there is one. Otherwise the icon core gives the module.
        def thematiq_app_row_icon(entry)
          if entry[:path]
            tag.svg(tag.path(d: entry[:path]), width: 22, height: 22, viewBox: "0 0 24 24", fill: "none",
                                               stroke: "currentColor", "stroke-width": "1.75",
                                               "stroke-linecap": "round", "stroke-linejoin": "round",
                                               "aria-hidden": "true", focusable: "false")
          elsif entry[:octicon].present?
            render(Primer::Beta::Octicon.new(icon: entry[:octicon], "aria-hidden": "true"))
          else
            tag.span(entry[:label].to_s.first.to_s.upcase, class: "thematiq-app-row--letter", "aria-hidden": "true")
          end
        end

        def thematiq_account_label
          role = thematiq_account_role
          tag.span(class: "thematiq-account") do
            concat tag.strong(User.current.name, class: "thematiq-account--name")
            concat tag.span(role, class: "thematiq-account--role") if role.present?
          end
        end

        # An administrator has every role, so the line says "Administrator". Anyone else sees
        # their roles in the current project. Outside a project there is no role to show.
        def thematiq_account_role
          user = User.current
          return User.human_attribute_name(:admin) if user.admin?
          return unless @project&.persisted?

          user.roles_for_project(@project).map(&:name).to_sentence.presence
        end
      end
    end
  end
end
