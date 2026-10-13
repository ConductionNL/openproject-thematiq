# frozen_string_literal: true

require "test_helper"
require "json"
require "open3"
require "open_project/thematiq/shell/project_menu"

# OpenProject's introduction tour pointed at core's return arrow, which the plugin's project menu hides
# (first full test, finding 8). The script drops those steps on their way into EnjoyHint. It runs here in Node,
# which the OpenProject image ships, against a stand-in for EnjoyHint that keeps what it is given.
class TourTest < Minitest::Test
  SCRIPT = OpenProject::Thematiq::Shell::ProjectMenu.tour_script

  def kept(steps, nested_menu: true)
    harness = <<~JS
      global.window = global;
      global.document = { querySelector: () => (#{nested_menu} ? {} : null) };
      #{SCRIPT}
      window.EnjoyHint = function () { const that = this; that.set = (data) => { that.data = data; }; };
      const tour = new window.EnjoyHint({});
      tour.set(#{JSON.generate(steps)});
      process.stdout.write(JSON.stringify(tour.data.map((step) => Object.keys(step)[0])));
    JS
    out, err, status = Open3.capture3("node", "-e", harness)
    skip "node is not available" if status.exitstatus == 127 || err.include?("No such file")
    assert status.success?, err
    JSON.parse(out)
  rescue Errno::ENOENT
    skip "node is not available"
  end

  STEPS = [{ "next .work-packages-tabletimeline--timeline-side" => "Timeline" },
           { "next [data-tour-selector=\"main-menu--arrow-left_gantt\"]" => "Use the return arrow" },
           { "next #boards-wrapper>.boards-menu-item" => "Select boards" }].freeze

  def test_the_steps_at_the_return_arrow_are_dropped_and_the_rest_kept_in_order
    assert_equal ["next .work-packages-tabletimeline--timeline-side", "next #boards-wrapper>.boards-menu-item"], kept(STEPS)
  end

  def test_without_the_plugins_menu_the_tour_is_left_as_core_wrote_it
    assert_equal 3, kept(STEPS, nested_menu: false).size
  end

  def test_the_page_renders_the_script_with_the_menu_script
    partial = File.read(File.expand_path("../../app/views/thematiq/shell/_body_bottom.html.erb", __dir__))

    assert_includes partial, "ProjectMenu.tour_script"
  end
end
