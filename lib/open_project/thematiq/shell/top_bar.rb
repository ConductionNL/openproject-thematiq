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
      #   lib/redmine/menu_manager/top_menu_helper.rb     (top_menu_left_menu_items)
      #   lib/redmine/menu_manager/top_menu/module_menu.rb (more_top_menu_items, read only)
      #   lib/redmine/menu_manager/top_menu/user_menu.rb  (lateral_user_menu_button)
      # CoreGuard holds their checksums. Shell.install! skips this module when they differ.
      module TopBar
        def self.install!
          helper = ::Redmine::MenuManager::TopMenuHelper
          helper.prepend(self) unless helper.ancestors.include?(self)
        end

        # Core returns the app switcher first, then the logo. The design puts the logo first, then
        # a row of apps and modules, then the app switcher as the "more" button.
        # Moving the elements, not just their CSS order, keeps the focus order equal to what you see.
        def top_menu_left_menu_items
          switcher, *rest = super
          rest + [thematiq_app_row, switcher].compact
        end

        private

        # Core puts whatever it gets as `avatar` inside the account button. Passing the avatar
        # plus the name and role adds them to the button without copying the core method.
        # Core skips the content block when there is no avatar, and then nothing is added.
        def lateral_user_menu_button(dialog, avatar)
          return super unless User.current.logged? && avatar.present?

          super(dialog, safe_join([avatar, thematiq_account_label]))
        end

        # The first apps and modules as icon links. Everything in the row is also in the app switcher,
        # so nothing is lost when the row is hidden on a narrow screen.
        def thematiq_app_row
          entries = thematiq_app_row_entries.first(Shell.top_bar_apps)
          return if entries.empty?

          tag.ul(class: "thematiq-app-row") do
            entries.each_with_index { |entry, index| concat thematiq_app_row_item(entry, index) }
          end
        end

        # Nextcloud's apps first, when an address is set, then OpenProject's global modules in the
        # order of the app switcher. The modules come from core's own menu and permission helpers.
        # A module the instance has no licence for stays in the app switcher, where core marks it.
        def thematiq_app_row_entries
          entries = []
          if (base = Shell.nextcloud_url)
            NextcloudApps::APPS.each do |app|
              entries << { label: t("thematiq.shell.app_switcher.apps.#{app.key}"),
                           href: NextcloudApps.url_for(app, base), path: app.icon, external: true }
            end
          end

          mine, others = more_top_menu_items.reject(&:heading?).partition { |item| item.context == :my }
          (mine + others).reject(&:enterprise_feature_missing?).each do |item|
            href = url_for(item.url)
            entries << { label: item.caption, href:, octicon: item.icon, current: AppRow.current?(request.path, href) }
          end
          entries
        end

        def thematiq_app_row_item(entry, index)
          id = "thematiq-app-row-#{index}"
          options = { id:, href: entry[:href], class: "thematiq-app-row--item", "aria-labelledby": "#{id}-name" }
          options[:"aria-current"] = "page" if entry[:current]
          options[:"data-allow-external-link"] = "true" if entry[:external]

          tag.li do
            concat tag.a(thematiq_app_row_icon(entry), **options)
            concat render(Primer::Alpha::Tooltip.new(for_id: id, id: "#{id}-name", type: :label, text: entry[:label].to_s,
                                                     direction: :s))
          end
        end

        # Nextcloud's apps use the outline icon of the design. A module uses the icon core gives it.
        def thematiq_app_row_icon(entry)
          if entry[:path]
            tag.svg(tag.path(d: entry[:path]), width: 20, height: 20, viewBox: "0 0 24 24", fill: "none",
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
