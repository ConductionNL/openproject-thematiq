# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Shell
      # The list under the nine-dot button, as the OpHeader board draws it: a heading, a column for Nextcloud and
      # one for OpenProject, a second line per entry, the current entry marked, "Manage apps" for an administrator,
      # and a button named "All apps and modules" that says whether the list is open.
      #
      # Core renders this list in TopMenu::ModuleMenu#render_module_top_menu_node, and sets the name of the button
      # inside that method. No hook reaches either, and core's list has no place for a second line or a current
      # mark. So the plugin renders its own list in place of core's, with the same Primer dialog, the same button
      # classes and core's own items: which modules a user sees is still core's decision, through
      # module_top_menu_item_groups. It calls core's two hooks of the dialog, so other plugins still add to it.
      #
      # Written against lib/redmine/menu_manager/top_menu/module_menu.rb of OpenProject 17.9.1, which CoreGuard
      # checks for the top bar. When it differs, this override is not installed and core's list renders. When
      # rendering fails, core's list renders and the log says why.
      module AppSwitcher
        DIALOG_ID = "thematiq-switcher"
        SCRIPT_PATH = File.expand_path("assets/app_switcher.js", __dir__)
        # The outline icon of the nine-dot button is drawn by the stylesheet. Core's icon name is kept for the fallback.
        CORE_ICON = "op-grid-menu"

        def self.install!
          helper = ::Redmine::MenuManager::TopMenuHelper
          helper.prepend(self) unless helper.ancestors.include?(self)
          @installed = true
        end

        def self.installed?
          @installed == true
        end

        def self.script
          @script ||= File.read(SCRIPT_PATH)
        end

        def render_module_top_menu_node(item_groups = module_top_menu_item_groups)
          items = item_groups.flat_map { |group| group[:items] }
          return super if items.empty?

          thematiq_switcher_dialog(items)
        rescue StandardError => e
          Rails.logger.error("[openproject-thematiq] The app switcher list fell back to core's: #{e.class}: #{e.message}")
          super
        end

        private

        def thematiq_switcher_dialog(items)
          columns = thematiq_switcher_columns(items)
          dialog = Primer::Alpha::Dialog.new(id: DIALOG_ID, classes: "op-app-menu--item thematiq-switcher",
                                             title: t("thematiq.shell.app_switcher.title"),
                                             size: :small, position: :left)
          render(dialog) do |d|
            d.with_show_button(icon: CORE_ICON, scheme: :invisible, classes: "op-app-header--primer-button",
                               test_selector: "op-app-header--modules-menu-button",
                               "aria-label": t("thematiq.shell.app_switcher.title"),
                               "aria-haspopup": "dialog", "aria-expanded": "false", "aria-controls": DIALOG_ID)
            d.with_body do
              safe_join([call_hook(:module_menu_dialog_content_before),
                         render(partial: "thematiq/shell/app_switcher", locals: { columns: }),
                         call_hook(:module_menu_dialog_content_after)])
            end
            d.with_footer(classes: "thematiq-switcher--footer") do
              safe_join([tag.span(t("thematiq.shell.app_switcher.keys")),
                         (link_to(t("thematiq.shell.app_switcher.manage"), admin_thematiq_path(anchor: "thematiq-top-bar"),
                                  class: "thematiq-switcher--manage") if User.current.admin?)].compact)
            end
          end
        end

        # [{ id:, title:, entries: [{ key, label, line, href, path, octicon, external, current, upsell }] }]
        def thematiq_switcher_columns(items)
          current = AppRow.current_key(current_menu_item)
          columns = []
          if (base = Shell.nextcloud_url)
            columns << { id: "nextcloud", title: t("thematiq.shell.app_switcher.nextcloud"),
                         entries: NextcloudApps::APPS.map do |app|
                           { key: app.key.to_s, label: t("thematiq.shell.app_switcher.apps.#{app.key}"),
                             href: NextcloudApps.url_for(app, base), path: app.icon, external: true }
                         end }
          end
          mine, others = items.partition { |item| item.context == :my }
          columns << { id: "openproject", title: Setting.app_title,
                       entries: (mine + others).map do |item|
                         key = item.name.to_s
                         { key:, label: item.caption, href: url_for(item.url), path: AppRow::ICONS[key], octicon: item.icon,
                           current: key == current, upsell: item.enterprise_feature_missing? }
                       end }
          columns.each { |column| column[:entries].each { |entry| entry[:line] = thematiq_switcher_line(entry[:key]) } }
        end

        # The second line of an entry. A module the plugin has no line for, from another plugin say, has none.
        def thematiq_switcher_line(key)
          t("thematiq.shell.app_switcher.lines.#{key}", default: "").presence
        end
      end
    end
  end
end
