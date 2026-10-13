# frozen_string_literal: true

module OpenProject
  module Thematiq
    # A design system per project and per module. See docs/design/scopes.md for the owner's decisions.
    #
    # This holds the rules and nothing that needs Rails, so the tests run with plain Ruby. The rows come from
    # the plugin's own table, Thematiq::Scope; the instance's choice stays in the plugin's settings (Store).
    #
    # Which choice wins, most specific first:
    #   1. this module in this project     content area only
    #   2. this project                    the whole page
    #   3. this module, instance wide      content area only
    #   4. a parent project, nearest first the whole page
    #   5. the instance                    the whole page
    #
    # A module choice reaches the content area only: a module is a view inside a place, not a place. So a page
    # has two answers: the design system of the whole page (top bar, logo, menu: rows 2, 4, 5) and the one of
    # its content (all five rows). Most pages give the same answer twice.
    module Scopes
      # The modules a choice can name, and the menu items of OpenProject 17.9.1 that belong to each.
      # A menu item that starts with "wiki-" is a wiki.
      MODULES = {
        "work_packages" => %w[work_packages work_packages_query_select],
        "gantt" => %w[gantt],
        "boards" => %w[boards board_view],
        "calendars" => %w[calendar_view calendars],
        "team_planners" => %w[team_planner_view team_planners],
        "meetings" => %w[meetings],
        "news" => %w[news],
        "documents" => %w[documents],
        "wiki" => %w[wiki wikis],
        "time_and_costs" => %w[costs cost_reports_global my_time_tracking time_entries],
        "backlogs" => %w[backlogs]
      }.freeze
      MODULE_NAME = /\A[a-z_]{1,40}\z/

      # project_id nil is a module choice for the whole instance. module_name "" is a choice for every module.
      Row = Struct.new(:project_id, :module_name, :design_system_id, keyword_init: true)

      # Where a choice came from, for the line that says so. kind: :module_in_project, :project, :module, :parent
      # or :instance. project_id names the project for :parent.
      Source = Struct.new(:kind, :project_id, :module_name, keyword_init: true)

      # page and content: [design system id, Source]. The id is nil for the instance's own choice.
      Resolution = Struct.new(:page, :content, keyword_init: true) do
        def split?
          page.first != content.first
        end
      end

      INSTANCE = Source.new(kind: :instance).freeze

      module_function

      # The module of a page, from the name of its current menu item. nil for a page of no module.
      def module_of(menu_item)
        name = menu_item.to_s
        return "wiki" if name.start_with?("wiki-")

        MODULES.find { |_module_name, items| items.include?(name) }&.first
      end

      # rows: every Row. chain: the page's project and its ancestors as ids, nearest first, or [] outside a project.
      # usable: a block that says whether a design system id still exists. A row naming one that does not is passed
      # over, as if it were not there.
      def resolve(rows:, chain:, module_name:, &usable)
        usable ||= ->(_id) { true }
        rows = rows.select { |row| usable.call(row.design_system_id) }
        project, *parents = chain
        find = ->(project_id, name) { rows.find { |row| row.project_id == project_id && row.module_name == name } }

        page_candidates = []
        page_candidates << [find.call(project, ""), Source.new(kind: :project, project_id: project)] if project
        parents.each { |parent| page_candidates << [find.call(parent, ""), Source.new(kind: :parent, project_id: parent)] }

        content_candidates = []
        if module_name && project
          content_candidates << [find.call(project, module_name), Source.new(kind: :module_in_project, project_id: project, module_name:)]
        end
        content_candidates << page_candidates.first if project
        content_candidates << [find.call(nil, module_name), Source.new(kind: :module, module_name:)] if module_name
        content_candidates.concat(project ? page_candidates.drop(1) : page_candidates)

        Resolution.new(page: winner(page_candidates), content: winner(content_candidates))
      end

      def winner(candidates)
        row, source = candidates.find { |candidate, _source| candidate }
        row ? [row.design_system_id, source] : [nil, INSTANCE]
      end
    end
  end
end
