# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Shell
      # The project menu from the OpNav design, on OpenProject's own menu.
      #
      # OpenProject builds the menu in helper methods and the project switcher in a view component,
      # so no view override and no hook reaches them. Every override here calls super and adds to
      # what core returns. Which items a user sees stays core's decision: the items still come from
      # OpenProject's menu and permission helpers.
      #
      # Written against OpenProject 17.9.1:
      #   lib/redmine/menu_manager/menu_helper.rb               (render_menu, render_menu_node,
      #                                                          render_menu_toggler, badge_for)
      #   lib/redmine/menu_manager/top_menu/projects_menu.rb    (render_projects_top_menu_node)
      #   app/components/header/project_select_component.rb     (trigger_label)
      # CoreGuard holds their checksums. Shell.install! skips this module when they differ.
      #
      # The two-layer menu itself is CSS and a small script on core's own markup: every item with a
      # submenu already has its second level as a ul inside its li. stylesheets/shell/30-nested-menu.css
      # shows that list under the item instead of in a swapped sidebar. Its rules only apply when
      # these overrides are on: they are scoped to the initials the switcher override renders.
      module ProjectMenu
        # Which title an item goes under. This only decides where a title is drawn.
        # An item that is not listed stays in the group of the item before it.
        GROUPS = {
          plan: %w[overview activity roadmap work_packages gantt calendar_view team_planner_view boards backlogs
                   resource_management],
          together: %w[meetings wiki news forums costs budgets documents repository]
        }.freeze

        # These sit at the foot of the menu, under a spacer and without a title.
        BOTTOM = %w[members settings].freeze

        # The script that keeps aria-expanded and aria-current in step with core's classes.
        # It is inlined at the end of the page, because the official image serves no plugin assets.
        SCRIPT_PATH = File.expand_path("assets/project_menu.js", __dir__)

        def self.script
          @script ||= File.read(SCRIPT_PATH)
        end

        PLUS_ICON = "M12 5v14M5 12h14"

        def self.install!
          helper = ::Redmine::MenuManager::MenuHelper
          helper.prepend(Helper) unless helper.ancestors.include?(Helper)

          component = ::Header::ProjectSelectComponent
          component.prepend(Switcher) unless component.ancestors.include?(Switcher)
        end

        # :plan, :together, :bottom or nil. Wiki items are named after their page, "wiki-<slug>".
        def self.group_for(name)
          name = name.to_s
          return :bottom if BOTTOM.include?(name)

          name = "wiki" if name.start_with?("wiki-")
          GROUPS.find { |_, names| names.include?(name) }&.first
        end

        # "Northwind rollout Lyon" gives "NR".
        def self.initials(name)
          name.to_s.split(/\s+/).first(2).filter_map { |word| word[/[[:alnum:]]/] }.join.upcase
        end

        module Helper
          # "Create work package" above the project switcher, for a user who may create one here.
          def render_projects_top_menu_node
            safe_join([thematiq_create_work_package_link, super].compact)
          end

          # Core renders the list. This only starts a fresh record of the titles drawn in it.
          def render_menu(menu, project = nil)
            @thematiq_nav_drawn = []
            super
          end

          # A group title, or the spacer above the bottom items, before the first item that needs one.
          def render_menu_node(node, project = nil)
            html = super
            return html unless @menu == :project_menu && html.present? && node.parent&.name == :root

            lead = thematiq_nav_lead(node)
            lead ? safe_join([lead, html], "\n") : html
          end

          private

          # Core names the arrow button after the item's title attribute, which is empty on the
          # selected item. Core never shows the arrow there. In the two-layer menu it shows on every
          # item with a submenu, so it gets its name. On other items the label is not empty and
          # nothing is replaced.
          def render_menu_toggler(node)
            html = super
            return html unless @menu == :project_menu

            nameless = %(aria-label="#{h(I18n.t(:label_go_forward, module: ''))}")
            named = %(aria-label="#{h(I18n.t(:label_go_forward, module: node.caption(@project)))}")
            html.sub(nameless, named).html_safe # rubocop:disable Rails/OutputSafety
          end

          # The number of open work packages the user may see in this project, on the menu item.
          def badge_for(item)
            core = super
            return core unless @menu == :project_menu && item.name == :work_packages && @project&.persisted?

            count = WorkPackage.visible(User.current).where(project_id: @project.id).with_status_open.count
            return core if count.zero?

            safe_join([core, thematiq_nav_count(count)].compact)
          end

          def thematiq_nav_count(count)
            tag.span(class: "thematiq-nav-count") do
              concat number_with_delimiter(count)
              concat tag.span(" #{t('thematiq.shell.project_menu.open')}", class: "sr-only")
            end
          end

          def thematiq_nav_lead(node)
            group = ProjectMenu.group_for(node.name)
            return if group.nil? || @thematiq_nav_drawn.include?(group)

            @thematiq_nav_drawn << group
            if group == :bottom
              tag.li(nil, class: "thematiq-nav-spacer", role: "presentation", aria: { hidden: true })
            else
              tag.li(t("thematiq.shell.project_menu.groups.#{group}"), class: "thematiq-nav-group")
            end
          end

          def thematiq_create_work_package_link
            return unless @project&.persisted? && User.current.allowed_in_project?(:add_work_packages, @project)

            link_to(new_project_work_packages_path(project_id: @project.identifier), class: "thematiq-nav-create") do
              concat thematiq_outline_icon(ProjectMenu::PLUS_ICON, size: 18)
              concat tag.span(t("thematiq.shell.project_menu.create_work_package"))
            end
          end

          # An outline icon as in the designs: 24 px grid, stroke 1.75, the colour of the text around it.
          # It is decoration, so it is hidden from screen readers. The text next to it is the name.
          def thematiq_outline_icon(path, size: 20)
            tag.svg(tag.path(d: path), width: size, height: size, viewBox: "0 0 24 24", fill: "none",
                                       stroke: "currentColor", "stroke-width": "1.75", "stroke-linecap": "round",
                                       "stroke-linejoin": "round", "aria-hidden": "true", focusable: "false")
          end
        end

        # The project switcher button: initials, a "Project" label and the name.
        module Switcher
          def trigger_label
            name = super
            return name if @current_project.nil?

            helpers.safe_join(
              [
                helpers.tag.span(ProjectMenu.initials(name), class: "thematiq-project--initials", "aria-hidden": "true"),
                helpers.tag.span(
                  helpers.safe_join(
                    [
                      helpers.tag.span(I18n.t("thematiq.shell.project_menu.project"), class: "thematiq-project--label"),
                      helpers.tag.strong(name, class: "thematiq-project--name")
                    ]
                  ),
                  class: "thematiq-project--text"
                )
              ]
            )
          end
        end
      end
    end
  end
end
