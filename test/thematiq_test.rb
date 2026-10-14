# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq"

# What the hooks put in the page head. Under plain Ruby there are no settings to read,
# which is the same situation as an error page shown while the database is away.
class ThematiqTest < Minitest::Test
  T = OpenProject::Thematiq

  def test_without_settings_the_default_design_system_is_used_and_nothing_raises
    assert_equal "cunningham", T.active_token_set.id
  end

  def test_a_store_that_raises_does_not_fail_the_page
    broken = Class.new do
      def read = raise(IOError, "database is away")
      def write(_) = raise(IOError, "database is away")
    end
    store = OpenProject::Thematiq::Store.new(backend: broken.new)

    assert_raises(IOError) { store.active_token_set }
    original = OpenProject::Thematiq::Store.method(:new)
    OpenProject::Thematiq::Store.define_singleton_method(:new) { |*| store }
    begin
      assert_equal "cunningham", T.active_token_set.id
    ensure
      OpenProject::Thematiq::Store.define_singleton_method(:new, original)
    end
  end

  def test_the_head_stylesheet_has_the_variable_layer_and_then_the_static_layers
    css = T.stylesheet

    assert_operator css.index("variable layer"), :<, css.index("geometry layer")
    assert_includes css, "--header-height: 68px"
    assert_includes css, ".thematiq-picker"
    refute_includes css, "<"
  end

  def test_the_early_stylesheet_is_the_variable_layer_only
    css = T.early_stylesheet

    assert_includes css, "body[data-color-mode]"
    refute_includes css, "--header-height"
    refute_includes css, "<"
  end

  def test_the_asset_stylesheet_names_only_files_under_the_plugins_own_path
    css = T.asset_stylesheet(root: "/op")

    assert_includes css, "font-family: 'Inter'", "Cunningham's second font ships with the plugin"
    css.scan(/url\(([^)]*)\)/).flatten.each { |url| assert_match(%r{\A/op/thematiq/(?:fonts|logos)/[a-z0-9-]+\.(?:woff2|svg)\z}, url) }
    refute_includes css, "<"
  end
end
