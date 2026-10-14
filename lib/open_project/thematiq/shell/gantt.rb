# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Shell
      # The Gantt page as the OpGantt board draws it. OpenProject draws the chart in Angular, so nothing here
      # replaces core: stylesheets/shell/60-gantt.css restyles core's own markup, and assets/gantt.js adds what
      # the board has and core does not render: the row of chips, Today, the zoom list, the view switch,
      # Export PDF, the legend, the board's header labels and the dependency lines (core draws its lines for
      # rows of 40 px; the table rows here are 48 px, see geometry/10-variables.css).
      #
      # Everything is scoped to the class "thematiq-gantt" on the body, which only the script sets. When a
      # guarded core file differs from OpenProject 17.9.1, the partial renders no script, so the class is never
      # set and core's own Gantt shows with the plugin's colours. See docs/shell-structure.md, "The Gantt page".
      module Gantt
        SCRIPT_PATH = File.expand_path("assets/gantt.js", __dir__)
        CONTROLLER = "gantt/gantt"

        def self.installed?
          return @installed unless @installed.nil?

          @installed = CoreGuard.changed_files(part: :gantt).empty?
        end

        # Tests set this back.
        def self.reset!
          @installed = nil
        end

        def self.script
          @script ||= File.read(SCRIPT_PATH)
        end

        # The script is only for the Gantt page of a project.
        def self.page?(controller:, project:)
          return false unless project && controller.respond_to?(:controller_path)

          controller.controller_path == CONTROLLER && controller.action_name == "index"
        end

        # The chips of the board: core's two default views of the Gantt module, with core's own query params, so
        # each chip opens the same view as its entry in the Gantt submenu. "Critical path" is left out: OpenProject
        # has no critical path. Milestones only shows when the project has a milestone type, as in core's submenu.
        def self.chips(project:, path:, open_count:)
          generator = ::Gantt::DefaultQueryGeneratorService.new(with_project: project)
          %i[all_open milestones].filter_map do |key|
            params = generator.call(query_key: key)
            next unless params

            { key: key.to_s, href: path.call(params), count: key == :all_open ? open_count : nil }
          end
        end

        # The open work packages of the project this user may see, for the count on "All open".
        def self.open_count(project:, user:)
          ::WorkPackage.visible(user).where(project:).joins(:status).where(statuses: { is_closed: false }).count
        end

        # What the script needs, as one JSON object. `t` translates a key under thematiq.shell.gantt.
        def self.kit(chips:, texts:)
          { chips:, texts: }
        end

        TEXT_KEYS = %w[
          chips_label all_open milestones today zoom zoom_levels.days zoom_levels.weeks zoom_levels.months
          zoom_levels.quarters zoom_levels.years view view_table view_board view_gantt export_pdf legend_label
          legend_bar legend_parent legend_milestone legend_follows timeline_label
        ].freeze

        def self.texts(translate)
          TEXT_KEYS.to_h { |key| [key.tr(".", "_"), translate.call("thematiq.shell.gantt.#{key}")] }
        end
      end
    end
  end
end
