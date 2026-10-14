# frozen_string_literal: true

require "test_helper"
require "yaml"
require "open_project/thematiq/shell/app_row"

# The admin field for the row of tiles: what it stores, and that Shell::AppRow reads it back the same.
class TopBarAppsSettingTest < Minitest::Test
  AppRow = OpenProject::Thematiq::Shell::AppRow

  def store(data = {})
    OpenProject::Thematiq::Store.new(backend: MemoryBackend.new(data))
  end

  def stored(store)
    store.instance_variable_get(:@backend).data["top_bar_apps"]
  end

  def test_a_fresh_install_has_the_row_of_the_design
    assert_equal ["default", AppRow::DEFAULT], store.top_bar_apps
  end

  def test_an_own_row_keeps_its_order_and_drops_empties_and_repeats
    s = store

    assert s.save_top_bar_apps("custom", ["gantt", "", "files", "gantt", "  boards "])
    assert_equal "gantt, files, boards", stored(s)
    assert_equal ["custom", %w[gantt files boards]], s.top_bar_apps
    assert_equal %w[gantt files boards], AppRow.wanted(stored(s)), "the shell reads what the field wrote"
  end

  def test_no_row_and_back_to_the_design
    s = store

    assert s.save_top_bar_apps("none", %w[files])
    assert_equal "none", stored(s)
    assert_equal ["none", []], s.top_bar_apps
    assert s.save_top_bar_apps("default", %w[files])
    assert_nil stored(s)
    assert_equal ["default", AppRow::DEFAULT], s.top_bar_apps
  end

  def test_refusals_store_nothing
    s = store("top_bar_apps" => "boards")
    refusals = [["custom", []], ["custom", ["", " "]], ["custom", AppRow::KNOWN.first(13)], ["custom", ["made_up"]],
                ["custom", ["files; } x {"]], ["custom", ["<script>"]], ["sideways", %w[files]], [nil, %w[files]]]
    refusals.each do |mode, keys|
      refute s.save_top_bar_apps(mode, keys), [mode, keys].inspect
      assert_equal "boards", stored(s)
    end
  end

  def test_a_key_the_setting_already_held_may_stay
    s = store("top_bar_apps" => "files, my_plugin_module")

    assert_equal ["custom", %w[files my_plugin_module]], s.top_bar_apps
    assert s.save_top_bar_apps("custom", %w[my_plugin_module files])
    assert_equal "my_plugin_module, files", stored(s)
  end

  def test_every_offered_key_is_a_valid_key_and_the_default_is_offered
    AppRow::KNOWN.each { |key| assert_match AppRow::KEY, key }
    assert_empty AppRow::DEFAULT - AppRow::KNOWN
    assert_equal AppRow::KNOWN.uniq, AppRow::KNOWN
  end

  def test_every_offered_key_has_a_label
    labels = YAML.load_file(File.expand_path("../../config/locales/en.yml", __dir__)).dig("en", "thematiq", "shell", "top_bar", "tiles")

    AppRow::KNOWN.each { |key| assert_kind_of String, labels[key], key }
  end
end
