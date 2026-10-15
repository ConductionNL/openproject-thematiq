# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Shell
      # The account menu as Nextcloud draws it: a dropdown under the avatar, not core's sheet that slides in from
      # the right. It opens on click and under the pointer, and closes on Escape, on a click outside and when the
      # pointer or the focus leaves it.
      #
      # Core renders the menu in TopMenu::UserMenu#render_user_drop_down(items), a private method that puts the items
      # in a Primer dialog placed at the right edge. A dialog is modal, so it cannot open under the pointer, and its
      # placement is the sheet. So for a signed in user the plugin renders its own disclosure in that method's place:
      # a button with aria-expanded and aria-controls, and a panel of links. The entries are core's: the items core
      # passes in, from the account menu with each item's own condition, so Administration still only shows to who
      # may open it, and each link keeps core's address and options (sign out keeps data-turbo="false"). An item
      # with a partial, such as the running timer, is rendered with core's partial at the top.
      #
      # Signed out, core's own dialog with the sign-in form renders. When rendering fails, core's dialog renders and
      # the log says why. Written against lib/redmine/menu_manager/top_menu/user_menu.rb of OpenProject 17.9.1, which
      # CoreGuard checks for the top bar.
      module AccountMenu
        BUTTON_ID = "thematiq-account-button"
        PANEL_ID = "thematiq-account-panel"
        SCRIPT_PATH = File.expand_path("assets/account_menu.js", __dir__)

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

        private

        def render_user_drop_down(items)
          return super unless User.current.logged?

          render(partial: "thematiq/shell/account_menu",
                 locals: { menu: thematiq_account_menu(items), button_id: AccountMenu::BUTTON_ID, panel_id: AccountMenu::PANEL_ID })
        rescue StandardError => e
          Rails.logger.error("[openproject-thematiq] The account menu fell back to core's: #{e.class}: #{e.message}")
          super
        end

        # { avatar:, name:, role:, partials: [partial names], links: [{ href:, label:, icon:, divider:, options: }] }
        def thematiq_account_menu(items)
          partial_items, link_items = items.partition { |item| item.partial.present? }
          {
            avatar: avatar(User.current, class: "op-top-menu-user-avatar", hover_card: { active: false },
                                         avatar_image_alt_text: ""),
            name: User.current.name,
            role: thematiq_account_role,
            partials: partial_items.map(&:partial),
            links: link_items.map do |item|
              { href: allowed_node_url(item, nil), label: item.caption, icon: item.icon,
                divider: item.show_divider_before?, options: (item.html_options || {}).symbolize_keys.except(:class, :data, :href),
                data: ((item.html_options || {}).symbolize_keys[:data] || {}).to_h
                                                                    .merge("thematiq-account-entry" => "", "test-selector" => "op-menu--item-action") }
            end
          }
        end
      end
    end
  end
end
