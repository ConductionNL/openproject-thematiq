# frozen_string_literal: true

require "test_helper"
require "yaml"

# The pages are not rendered in these tests, so a missing translation would only show in a running OpenProject.
# This test reads the keys out of the code and looks each one up in en.yml.
class LocaleTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  EN = YAML.load_file(File.join(ROOT, "config/locales/en.yml")).fetch("en")
  SOURCES = Dir[File.join(ROOT, "{app,lib}/**/*.{rb,erb}")].sort

  def lookup(key)
    key.split(".").reduce(EN) { |node, part| node.is_a?(Hash) ? node[part] : nil }
  end

  def test_every_literal_key_in_the_code_exists
    keys = SOURCES.flat_map { |file| File.read(file).scan(/\bt\(\s*"(thematiq\.[a-z0-9_.-]+)"/).flatten }.uniq

    assert_operator keys.size, :>, 10
    keys.each { |key| refute_nil lookup(key), "missing translation #{key}" unless key.end_with?(".") }
  end

  def test_every_token_has_a_label_and_a_hint
    OpenProject::Thematiq::Tokens::TokenSet::KINDS.each_key do |key|
      assert_kind_of String, lookup("thematiq.tokens.#{key}.label"), key
      assert_kind_of String, lookup("thematiq.tokens.#{key}.hint"), key
    end
  end

  def test_every_kind_has_a_hint_and_an_error
    OpenProject::Thematiq::Tokens::TokenSet::KINDS.values.uniq.each do |kind|
      assert_kind_of String, lookup("thematiq.editor.kind_hint.#{kind}")
      assert_kind_of String, lookup("thematiq.editor.error_#{kind}")
    end
  end

  def test_every_interpolated_key_prefix_in_the_code_has_entries
    prefixes = SOURCES.flat_map { |file| File.read(file).scan(/\bt\(\s*"(thematiq\.[a-z0-9_.-]+\.)#\{/).flatten }.uniq

    prefixes.each { |prefix| assert_kind_of Hash, lookup(prefix.chomp(".")), "no entries under #{prefix}" }
  end

  def test_the_text_follows_the_house_style
    strings = []
    walk = ->(node) { node.is_a?(Hash) ? node.each_value(&walk) : strings << node.to_s }
    walk.call(EN)

    strings.each do |text|
      refute_match(/—|–| -- /, text, "dash in #{text.inspect}")
      refute_match(/\A[A-Z][a-z]+ [A-Z][a-z]+ [A-Z][a-z]+/, text, "title case in #{text.inspect}")
    end
  end
end
