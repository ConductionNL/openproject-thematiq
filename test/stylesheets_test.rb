# frozen_string_literal: true

require "test_helper"

# The static layers are inlined in a <style> tag as they are, so they get a few structural checks.
class StylesheetsTest < Minitest::Test
  FILES = Dir[File.expand_path("../stylesheets/**/*.css", __dir__)].sort

  def test_there_are_static_layers
    refute_empty FILES
  end

  def test_no_file_can_close_the_style_tag
    FILES.each { |file| refute_includes File.read(file), "<", file }
  end

  def test_braces_are_balanced
    FILES.each do |file|
      css = File.read(file).gsub(%r{/\*.*?\*/}m, "")

      assert_equal css.count("{"), css.count("}"), file
    end
  end

  def test_no_text_is_written_with_generated_content
    FILES.each do |file|
      css = File.read(file).gsub(%r{/\*.*?\*/}m, "")

      refute_match(/content\s*:\s*["'][^"']*[A-Za-z]/, css, "#{file} writes text with generated content")
    end
  end

  def test_colours_come_from_variables
    FILES.each do |file|
      next if File.basename(file) == "10-variables.css"

      css = File.read(file).gsub(%r{/\*.*?\*/}m, "")

      refute_match(/#\h{3,8}\b/, css, "#{file} has a colour literal")
    end
  end

  def test_only_aliases_the_variable_layer_defines_are_used
    defined = OpenProject::Thematiq::Variables::Generator::COLOR_ALIASES.keys +
              OpenProject::Thematiq::Variables::Generator::ROOT_SHAPE.keys +
              OpenProject::Thematiq::Variables::Generator::BAR_TINTS.keys + ["--thematiq-table-head"] +
              OpenProject::Thematiq::Variables::Generator::VOCABULARY_COLORS.keys.grep(/\A--thematiq-v-/) +
              OpenProject::Thematiq::Variables::Generator::VOCABULARY_SHAPE.keys.grep(/\A--thematiq-v-/)
    used = FILES.flat_map { |file| File.read(file).scan(/var\((--thematiq-[a-z-]+)/).flatten }.uniq

    assert_empty used - defined
  end
end
