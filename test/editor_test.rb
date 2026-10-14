# frozen_string_literal: true

require "test_helper"
require "yaml"
require "open_project/thematiq/editor"
require "open_project/thematiq/preview"

class EditorTest < Minitest::Test
  Editor = OpenProject::Thematiq::Editor
  TokenSet = OpenProject::Thematiq::Tokens::TokenSet
  Contrast = OpenProject::Thematiq::Contrast
  ROOT = File.expand_path("..", __dir__)
  EN = YAML.load_file(File.join(ROOT, "config/locales/en.yml")).fetch("en").fetch("thematiq")
  SCRIPT = File.read(Editor::SCRIPT_PATH)
  VIEW = File.read(File.join(ROOT, "app/views/thematiq/admin/edit.html.erb"))

  def set(tokens)
    TokenSet.from_set({ "id" => "t", "name" => "T", "tokens" => tokens })
  end

  def test_every_token_is_in_exactly_one_group
    keys = Editor.groups.flat_map(&:keys)

    assert_equal (TokenSet::ALL_KINDS.keys + OpenProject::Thematiq::Tokens::Vocabulary.keys).sort, keys.sort
    assert_equal keys.uniq, keys
  end

  def test_the_roles_come_first_and_the_vocabulary_groups_hold_only_vocabulary
    roles, vocabulary = Editor.groups.partition { |group| !group.vocabulary }

    assert_equal TokenSet::ALL_KINDS.keys.sort, roles.flat_map(&:keys).sort
    assert_equal Editor.groups.first(roles.size), roles, "the four groups of the roles come before the vocabulary"
    vocabulary.each { |group| refute_empty group.keys, group.id }
  end

  def test_every_vocabulary_key_has_a_label_and_every_kind_a_hint_and_an_error
    OpenProject::Thematiq::Tokens::Vocabulary::KINDS.each do |key, kind|
      assert_kind_of String, EN.dig("vocabulary", key), key
      assert_kind_of String, EN.dig("editor", "kind_hint", kind.to_s), kind
      assert_kind_of String, EN.dig("editor", "error_#{kind}"), kind
    end
  end

  def test_reset_group_names_a_vocabulary_group
    assert_includes Editor.keys_of("status"), "color-error"
    refute_includes Editor.keys_of("status"), "primary"
  end

  def test_every_group_has_a_label_and_a_hint
    Editor.groups.each do |group|
      assert_kind_of String, EN.dig("editor", "groups", group.id, "label"), group.id
      assert_kind_of String, EN.dig("editor", "groups", group.id, "hint"), group.id
    end
  end

  def test_the_keys_of_an_unknown_group_are_none
    assert_equal [], Editor.keys_of("nothing")
    assert_equal [], Editor.keys_of(nil)
    assert_equal [], Editor.keys_of(["branding"])
    assert_equal %w[action action-deep link], Editor.keys_of("buttons")
  end

  def test_every_check_is_one_the_contrast_report_knows_and_has_a_label
    with_menu = set("menu" => "#123456")

    Editor::CHECKS.each do |check|
      assert Contrast.report(with_menu).key?(check.id), check.id
      assert_kind_of String, EN.dig("contrast", "pairs", check.id), check.id
      check.tokens.each { |key| assert_equal :color, TokenSet::ALL_KINDS.fetch(key), "#{check.id} #{key}" }
    end
  end

  def test_every_pair_of_the_contrast_report_is_shown_next_to_a_token
    assert_equal Contrast.report(set("menu" => "#123456")).keys.sort, Editor::CHECKS.map(&:id).sort
  end

  def test_the_ratio_and_the_verdict
    check = Editor::CHECKS.find { |candidate| candidate.id == "ink-on-ground" }

    assert_equal "pass", Editor.verdict(Editor.ratio(check, set("ink" => "#000000", "ground" => "#ffffff")))
    assert_equal "fail", Editor.verdict(Editor.ratio(check, set("ink" => "#cccccc", "ground" => "#ffffff")))
    assert_equal "unknown", Editor.verdict(Editor.ratio(check, set("ink" => "oklch(0.5 0.1 200)", "ground" => "#ffffff")))
  end

  def test_the_menu_check_does_not_apply_without_a_menu_colour
    check = Editor::CHECKS.find { |candidate| candidate.id == "text-on-menu" }

    assert_nil Editor.ratio(check, set({}))
    refute_nil Editor.ratio(check, set("menu" => "#123456"))
  end

  def test_the_script_data_holds_only_the_plugins_own_data
    data = Editor.script_data

    assert_equal Editor::KINDS.keys, data["kinds"].keys
    assert_equal TokenSet::ALL_KINDS.keys, data["preview"], "the picture only reads the roles"
    assert_equal Editor::CHECKS.size, data["checks"].size
    assert_equal 4.5, data["minimum"]
    assert_includes data["named"], "rebeccapurple"
  end

  # The script is inlined in a script tag, so it gets the checks the stylesheets get.
  def test_the_script_cannot_close_its_tag_and_reaches_nowhere
    refute_match(%r{</script|<!--}i, SCRIPT)
    refute_match(/fetch\(|XMLHttpRequest|WebSocket|EventSource|sendBeacon|import\(|eval\(|new Function|innerHTML|outerHTML|document\.write|localStorage|cookie/, SCRIPT)
  end

  def test_the_script_uses_the_validators_patterns
    validator = OpenProject::Thematiq::Tokens::Validator

    assert_includes SCRIPT, "rgba?|hsla?|hwb|lab|lch|oklab|oklch"
    assert_includes validator::COLOR_FUNCTION.source, "rgba?|hsla?|hwb|lab|lch|oklab|oklch"
    assert_includes SCRIPT, "px|rem|em|%"
    assert_includes validator::LENGTH.source, "px|rem|em|%"
  end

  # Each new kind's pattern is written twice, in Ruby and in the script. They must say the same.
  def test_the_script_has_the_validators_patterns_for_the_vocabulary
    validator = OpenProject::Thematiq::Tokens::Validator
    js = ->(pattern) { pattern.source.gsub("\\A", "^").gsub("\\z", "$") }

    [validator::SIZE, validator::FONT_WEIGHT, validator::NUMBER, validator::DURATION, validator::RGB_TRIPLET,
     validator::FILTER_FUNCTION, validator::BORDER].each { |pattern| assert_includes SCRIPT, js.call(pattern), pattern.source }
    validator::TEXT_TRANSFORMS.each { |word| assert_includes SCRIPT, word }
  end

  def test_the_script_writes_the_properties_the_preview_reads
    assert_includes SCRIPT, %("#{OpenProject::Thematiq::Preview::PREFIX}")
    OpenProject::Thematiq::Preview.new(TokenSet.fallback).derived.each_key { |name| assert_includes SCRIPT, %("#{name}") }
  end

  def test_the_page_inlines_the_script_with_a_nonce_and_has_no_handler_attribute
    assert_includes VIEW, "nonced_javascript_tag"
    refute_match(/\son[a-z]+=/, VIEW)
    refute_match(/<script/, VIEW)
  end

  def test_the_stylesheet_reads_only_properties_the_preview_writes
    css = File.read(File.join(ROOT, "stylesheets/admin/80-editor.css"))
    written = OpenProject::Thematiq::Preview.new(TokenSet.fallback).shell_variables.scan(/--tqp-[a-z-]+/)

    assert_empty css.scan(/var\((--tqp-[a-z-]+)/).flatten.uniq - written
  end
  def test_every_colour_has_a_dark_field_and_nothing_else_has
    assert_equal Editor::KINDS.select { |_key, kind| kind == :color }.keys, Editor::DARK_FIELDS
    assert_includes Editor::DARK_FIELDS, "primary"
    assert_includes Editor::DARK_FIELDS, "color-error"
    refute_includes Editor::DARK_FIELDS, "radius"
    assert_empty TokenSet::DARK_KEYS - Editor::DARK_FIELDS, "every dark role of a set has a field"
  end

  def test_the_page_has_a_dark_field_an_opacity_text_and_the_scope_choice
    assert_includes VIEW, 'name="dark[<%= key %>]"'
    assert_includes VIEW, "data-thematiq-scope"
    %w[opacity dark.label dark.field_label dark.base_value dark.own_value scope.label scope.page scope.module scope.page_hint
       scope.module_hint scope.used_title].each { |key| assert_kind_of String, EN.dig("editor", *key.split(".")), key }
  end

  # thematiq writes #rrggbb at full opacity and #rrggbbaa below it. The script does the same.
  def test_the_script_writes_the_opacity_as_an_eight_digit_hex
    assert_includes SCRIPT, "function withAlpha"
    assert_includes SCRIPT, 'opacity.type = "range"'
    assert_includes SCRIPT, "alpha >= 100 ? hex : hex + hexByte"
  end
  # The apply dialog's script sends its own form, to the plugin, and nothing else.
  def test_the_compare_script_sends_only_its_form_and_writes_no_markup
    script = File.read(Editor::COMPARE_SCRIPT_PATH)

    refute_match(%r{</script|<!--}i, script)
    refute_match(/XMLHttpRequest|WebSocket|EventSource|sendBeacon|import\(|eval\(|new Function|innerHTML|outerHTML|insertAdjacentHTML|document\.write|localStorage|cookie/, script)
    assert_equal 1, script.scan("fetch(").size
    assert_includes script, "window.fetch(form.action"
    assert_includes script, 'credentials: "same-origin"'
    assert_includes script, "element.textContent = css"
  end
end
