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
    OpenProject::Thematiq::Tokens::TokenSet::ALL_KINDS.each_key do |key|
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
      # I18n keeps these names for itself. A text that uses one fails only when the page is drawn.
      refute_match(/%\{(?:format|scope|default|locale|raise|throw|fallback|separator|exception_handler|rescue_format)\}/, text, "reserved name in #{text.inspect}")
    end
  end
end

# The keys of the upload section are built from the kinds, the weights and the error codes,
# so the scan above does not see them. This class looks each one up.
class UploadsLocaleTest < Minitest::Test
  Uploads = OpenProject::Thematiq::Uploads
  EN = LocaleTest::EN
  ROOT = LocaleTest::ROOT

  def lookup(key)
    key.split(".").reduce(EN) { |node, part| node.is_a?(Hash) ? node[part] : nil }
  end

  def test_every_kind_has_a_label_and_a_hint
    Uploads::KINDS.each_key do |kind|
      assert_kind_of String, lookup("thematiq.uploads.kinds.#{kind}.label"), kind
      assert_kind_of String, lookup("thematiq.uploads.kinds.#{kind}.hint"), kind
    end
  end

  def test_every_weight_and_style_has_a_name
    Uploads::FontFace::WEIGHTS.each { |weight| assert_kind_of String, lookup("thematiq.uploads.weights.w#{weight.tr(' ', '_')}"), weight }
    Uploads::FontFace::STYLES.each { |style| assert_kind_of String, lookup("thematiq.uploads.styles.#{style}"), style }
  end

  def test_every_error_the_controller_passes_on_has_a_message
    controller = File.read(File.join(ROOT, "app/controllers/thematiq/admin_controller.rb"))
    codes = controller[/UPLOAD_ERRORS = %w\[(.*?)\]/m, 1].split

    assert_operator codes.size, :>, 10
    codes.each { |code| assert_kind_of String, lookup("thematiq.uploads.errors.#{code}"), code }
  end

  def test_every_code_the_checks_raise_is_one_the_controller_passes_on
    controller = File.read(File.join(ROOT, "app/controllers/thematiq/admin_controller.rb"))
    codes = controller[/UPLOAD_ERRORS = %w\[(.*?)\]/m, 1].split
    sources = Dir[File.join(ROOT, "{lib/open_project/thematiq/uploads,app/models/thematiq,app/controllers/thematiq}/**/*.rb")] +
              [File.join(ROOT, "lib/open_project/thematiq/uploads.rb")]
    raised = sources.flat_map { |file| File.read(file).scan(/(?<!Transfer::)(?<!CssTokens::)Refused, "([a-z_]+)"/).flatten }.uniq

    assert_operator raised.size, :>, 10
    assert_empty raised - codes
  end

  def test_every_error_of_the_css_upload_has_a_message
    controller = File.read(File.join(ROOT, "app/controllers/thematiq/admin_controller.rb"))
    codes = controller[/CSS_ERRORS = %w\[(.*?)\]/m, 1].split
    raised = File.read(File.join(ROOT, "lib/open_project/thematiq/css_tokens.rb")).scan(/Refused, "([a-z_]+)"/).flatten.uniq

    assert_empty raised - codes
    codes.each { |code| assert_kind_of String, lookup("thematiq.css_upload.errors.#{code}"), code }
  end

  def test_every_key_the_files_partial_picks_between_exists
    partial = File.read(File.join(ROOT, "app/views/thematiq/admin/_files.html.erb"))
    keys = partial.scan(/"(thematiq\.uploads\.[a-z_.]+)"/).flatten.uniq.reject { |key| key.end_with?(".") }

    assert_operator keys.size, :>, 15
    keys.each { |key| refute_nil lookup(key), key }
  end

  # An error message may only name numbers the controller hands it.
  def test_error_messages_only_use_the_values_the_controller_gives
    lookup("thematiq.uploads.errors").each do |code, text|
      assert_empty text.scan(/%\{(\w+)\}/).flatten - %w[types size min width height count], code
    end
  end
end
