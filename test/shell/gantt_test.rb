# frozen_string_literal: true

require "test_helper"
require "yaml"
require "open_project/thematiq/shell/core_guard"
require "open_project/thematiq/shell/gantt"

class GanttTest < Minitest::Test
  Shell = OpenProject::Thematiq::Shell
  ROOT = File.expand_path("../..", __dir__)
  EN = YAML.load_file(File.join(ROOT, "config/locales/en.yml")).fetch("en")

  FakeController = Struct.new(:controller_path, :action_name)

  def test_the_guard_has_a_gantt_part_with_checksums
    part = Shell::CoreGuard::PARTS.fetch(:gantt)

    refute_empty part
    part.each { |path| assert Shell::CoreGuard::FILES.key?(path), "#{path} has no checksum" }
  end

  def test_the_script_only_runs_on_a_projects_gantt_page
    assert Shell::Gantt.page?(controller: FakeController.new("gantt/gantt", "index"), project: Object.new)
    refute Shell::Gantt.page?(controller: FakeController.new("gantt/gantt", "index"), project: nil)
    refute Shell::Gantt.page?(controller: FakeController.new("work_packages", "index"), project: Object.new)
    refute Shell::Gantt.page?(controller: nil, project: Object.new)
  end

  def test_every_text_of_the_script_is_translated
    texts = Shell::Gantt.texts(->(key) { key.split(".").reduce(EN) { |node, part| node.is_a?(Hash) ? node[part] : nil } })

    texts.each do |name, value|
      assert_kind_of String, value, "thematiq.shell.gantt: #{name} is missing"
      refute_includes value, "—", name
    end
    assert_equal "Today", texts["today"]
    assert_equal "Days", texts["zoom_levels_days"]
  end

  def test_the_script_reads_every_text_it_gets
    script = Shell::Gantt.script

    Shell::Gantt::TEXT_KEYS.map { |key| key.tr(".", "_") }.reject { |key| key.start_with?("zoom_levels_") || %w[all_open milestones].include?(key) }.each do |key|
      assert_match(/T(\.#{key}\b|\["#{key}"\])|"#{key}"/, script, "the script never reads #{key}")
    end
    assert_includes script, '"zoom_levels_" + level'
  end

  def test_the_stylesheet_only_applies_with_the_class_the_script_sets
    css = File.read(File.join(ROOT, "stylesheets/shell/60-gantt.css")).gsub(%r{/\*.*?\*/}m, "")
    selectors = css.scan(/(?:^|\})\s*([^{}@]+)\{/).flatten.flat_map { |group| group.split(",") }.map(&:strip).reject(&:empty?)

    refute_empty selectors
    selectors.each { |selector| assert selector.start_with?("body.thematiq-gantt"), selector }
  end
end
