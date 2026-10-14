# frozen_string_literal: true

require "test_helper"
require "yaml"
require "open_project/thematiq/shell/core_guard"
require "open_project/thematiq/shell/create_dialog"

class CreateDialogTest < Minitest::Test
  Shell = OpenProject::Thematiq::Shell
  ROOT = File.expand_path("../..", __dir__)
  EN = YAML.load_file(File.join(ROOT, "config/locales/en.yml")).fetch("en")

  User = Struct.new(:logged) do
    def logged? = logged
  end

  def translate
    ->(key) { key.split(".").reduce(EN) { |node, part| node.is_a?(Hash) ? node[part] : nil } }
  end

  def test_the_guard_has_a_create_dialog_part_with_checksums
    part = Shell::CoreGuard::PARTS.fetch(:create_dialog)

    assert_includes part, "app/controllers/work_packages/dialogs_controller.rb"
    part.each { |path| assert Shell::CoreGuard::FILES.key?(path), "#{path} has no checksum" }
  end

  def teardown
    Shell::CreateDialog.reset!
  end

  def test_only_a_signed_in_user_gets_the_script
    Shell::CreateDialog.instance_variable_set(:@installed, true)

    assert Shell::CreateDialog.render?(User.new(true))
    refute Shell::CreateDialog.render?(User.new(false))
  end

  def test_no_script_when_a_guarded_file_differs
    Shell::CreateDialog.instance_variable_set(:@installed, false)

    refute Shell::CreateDialog.render?(User.new(true))
  end

  def test_the_kit_has_the_board_texts_and_the_root_without_a_trailing_slash
    kit = Shell::CreateDialog.kit(root: "/openproject/", translate:)

    assert_equal "/openproject", kit[:root]
    assert_equal({ "title" => "Create work package", "submit" => "Create work package" }, kit[:texts])
    assert_equal "", Shell::CreateDialog.kit(root: nil, translate:)[:root]
  end

  def test_the_script_sends_core_create_pages_to_core_dialog
    script = Shell::CreateDialog.script

    assert_includes script, "/work_packages/dialog/new"
    assert_includes script, "text/vnd.turbo-stream.html"
    assert_includes script, "renderStreamMessage"
    assert_includes script, "work_packages\\/new|(?:[^\\/]+\\/)*create_new"
    refute_includes script, "—"
  end

  def test_the_stylesheet_only_applies_with_the_class_the_script_sets
    css = File.read(File.join(ROOT, "stylesheets/shell/70-create-modal.css")).gsub(%r{/\*.*?\*/}m, "")
    selectors = css.scan(/(?:^|\})\s*([^{}@]+)\{/).flatten.flat_map { |group| group.split(",") }.map(&:strip).reject(&:empty?)

    refute_empty selectors
    selectors.each { |selector| assert selector.start_with?("body.thematiq-create-dialog"), selector }
  end
end
