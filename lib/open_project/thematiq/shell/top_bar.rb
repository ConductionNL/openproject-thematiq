# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Shell
      # OpenProject builds its top bar in helper methods, not in a view, so a view override
      # cannot reach it and no hook renders inside the logo block or the account button.
      # These three overrides are the smallest change that puts real text in both places.
      # Each one calls super and only adds to or reorders what core returns.
      #
      # Written against OpenProject 17.9.1:
      #   lib/redmine/menu_manager/top_menu_helper.rb     (top_menu_left_menu_items, render_logo)
      #   lib/redmine/menu_manager/top_menu/user_menu.rb  (lateral_user_menu_button)
      # CoreGuard holds their checksums. Shell.install! skips this module when they differ.
      module TopBar
        def self.install!
          helper = ::Redmine::MenuManager::TopMenuHelper
          helper.prepend(self) unless helper.ancestors.include?(self)
        end

        # Core returns the app switcher first, then the logo. The design puts the logo first.
        # Moving the element, not just its CSS order, keeps the focus order equal to what you see.
        def top_menu_left_menu_items
          switcher, *rest = super
          rest + [switcher]
        end

        # The app name as real text after the logo: translatable, and read by a screen reader.
        # It is the title an admin sets under Administration, System settings, General.
        def render_logo
          safe_join([super, tag.strong(Setting.app_title, class: "thematiq-app-name")])
        end

        private

        # Core puts whatever it gets as `avatar` inside the account button. Passing the avatar
        # plus the name and role adds them to the button without copying the core method.
        # Core skips the content block when there is no avatar, and then nothing is added.
        def lateral_user_menu_button(dialog, avatar)
          return super unless User.current.logged? && avatar.present?

          super(dialog, safe_join([avatar, thematiq_account_label]))
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
