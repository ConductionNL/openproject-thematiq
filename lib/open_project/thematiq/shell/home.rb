# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Shell
      # Home and My page as one page.
      #
      # In OpenProject, Home is a page of fixed blocks rendered on the server, and My page is a grid
      # of widgets per user, drawn by the Angular element "opce-my-page". That element always loads
      # the grid of the My page, whatever page it sits on. So for a signed in user Home renders the
      # greeting, the administrator's welcome text, the user's own grid, and then the Home blocks
      # that have no widget. The address of My page leads to Home, and the menus show one item.
      #
      # An anonymous visitor gets OpenProject's own Home, unchanged: My page needs a user.
      #
      # Written against OpenProject 17.9.1:
      #   app/controllers/homescreen_controller.rb                (index)
      #   app/views/homescreen/index.html.erb                     (what the merged page must keep)
      #   app/components/homescreen/blocks_grid_component.rb      (takes anything that answers [:blocks])
      #   config/initializers/homescreen.rb                       (the block named "welcome")
      #   modules/my_page/app/controllers/my/page_controller.rb   (show)
      # CoreGuard holds their checksums. Shell.install! skips this module when they differ.
      module Home
        # The menus that list My page next to Home.
        MENUS = %i[top_menu global_menu account_menu].freeze
        WELCOME_BLOCK = "welcome"

        def self.install!
          controller = ::HomescreenController
          controller.prepend(HomePage) unless controller.ancestors.include?(HomePage)

          my_page = ::My::PageController
          my_page.prepend(MyPage) unless my_page.ancestors.include?(MyPage)

          return if @menus_changed

          @menus_changed = true
          MENUS.each do |menu_name|
            ::Redmine::MenuManager.map(menu_name) { |menu| menu.delete(:my_page) }
          end
        end

        # The Home blocks without the welcome text, which the merged page shows above the grid.
        # The answer has the one method Homescreen::BlocksGridComponent asks for.
        def self.other_blocks(homescreen)
          { blocks: Array(homescreen[:blocks]).reject { |block| block[:name].to_s == WELCOME_BLOCK } }
        end

        # Whether the administrator's welcome text is on, from the block's own condition.
        def self.welcome?(homescreen)
          block = Array(homescreen[:blocks]).find { |candidate| candidate[:name].to_s == WELCOME_BLOCK }
          !block.nil? && (block[:if].nil? || block[:if].call)
        end

        module HomePage
          def index
            super
            return if performed? || !User.current.logged?

            render "thematiq/shell/home", layout: "no_menu"
          end
        end

        module MyPage
          def show
            redirect_to home_path
          end
        end
      end
    end
  end
end
