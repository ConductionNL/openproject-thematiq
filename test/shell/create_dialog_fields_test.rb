# frozen_string_literal: true

require "test_helper"
require "yaml"
require "open_project/thematiq/shell/core_guard"
require "open_project/thematiq/shell/create_dialog_fields"

class CreateDialogFieldsTest < Minitest::Test
  Fields = OpenProject::Thematiq::Shell::CreateDialogFields
  Guard = OpenProject::Thematiq::Shell::CoreGuard
  ROOT = File.expand_path("../..", __dir__)
  EN = YAML.load_file(File.join(ROOT, "config/locales/en.yml")).fetch("en")

  def test_the_board_fields_in_its_order
    assert_equal %i[parent assignee priority start_date due_date], Fields::ATTRIBUTES.keys
  end

  def test_only_what_the_contract_lets_the_user_write_is_rendered
    assert_equal %w[parent_id priority_id], Fields.rendered(%w[subject parent_id priority_id assigned_to])
    assert_empty Fields.rendered([])
  end

  def test_core_hidden_fields_leave_out_both_names_of_a_rendered_attribute
    assert_equal %w[assigned_to_id assigned_to start_date], Fields.names(%w[assigned_to_id start_date])
  end

  def test_every_field_writer_exists
    Fields::ATTRIBUTES.each_value do |attribute|
      assert Fields::FormFields.private_method_defined?(:"thematiq_#{attribute}_field"), attribute
    end
  end

  def test_the_files_it_leans_on_are_guarded_with_the_dialog
    part = Guard::PARTS.fetch(:create_dialog)

    %w[app/forms/work_packages/dialogs/create_form.rb app/forms/custom_fields/custom_field_rendering.rb
       lib/primer/open_project/forms/dsl/input_methods.rb lib/primer/open_project/forms/autocompleter.rb
       app/models/permitted_params.rb].each do |path|
      assert_includes part, path
      assert Guard::FILES.key?(path), path
    end
  end

  def test_the_nextcloud_line_and_its_note_are_translated
    texts = EN.dig("thematiq", "shell", "create_dialog")

    assert_equal "Link the project folder in Nextcloud", texts["nextcloud_folder"]
    assert_includes texts["nextcloud_folder_note"], "administrator"
    refute_includes texts.values.join, "—"
  end
end
