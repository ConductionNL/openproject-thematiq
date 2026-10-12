# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/preview"

class PreviewTest < Minitest::Test
  TokenSet = OpenProject::Thematiq::Tokens::TokenSet
  Preview = OpenProject::Thematiq::Preview

  # One style attribute: "property: value" pairs, nothing that could leave the attribute or load anything.
  SAFE_STYLE = /\A(?:[a-z-]+: [#A-Za-z0-9 .,%()'\/_-]+(?:; |\z))+\z/

  def set(tokens)
    TokenSet.from_set({ "id" => "t", "name" => "T", "tokens" => tokens })
  end

  def all_styles(token_set)
    preview = Preview.new(token_set)
    preview.thumbnail.values + preview.shell.values + Preview::NEUTRAL.keys.map { |key| preview.swatch(key) }
  end

  def assert_safe(styles, label)
    styles.each do |style|
      assert_match SAFE_STYLE, style, label
      refute_match(/url|expression|javascript|import|display|position|["<>{}\\@]/i, style, label)
    end
  end

  def test_the_thumbnail_uses_the_tokens
    thumbnail = Preview.new(set("primary" => "#aa0055", "action" => "#00aa55", "radius" => "9px")).thumbnail

    assert_equal "background: #aa0055", thumbnail[:top_bar]
    assert_includes thumbnail[:button], "background: #00aa55"
    assert_includes thumbnail[:button], "border-radius: 9px"
  end

  def test_the_shell_uses_the_tokens
    shell = Preview.new(set("primary" => "#aa0055", "font-family" => "'Fira Sans', sans-serif", "ink" => "#111111")).shell

    assert_includes shell[:top_bar], "background: #aa0055"
    assert_includes shell[:frame], "font-family: 'Fira Sans', sans-serif"
    assert_includes shell[:frame], "color: #111111"
  end

  def test_a_set_without_a_token_gets_a_neutral_value
    preview = Preview.new(TokenSet.fallback)

    assert_safe all_styles(TokenSet.fallback), "fallback"
    assert_equal "background: #{OpenProject::Thematiq::Tokens::Defaults::TOKENS['primary']}", preview.thumbnail[:top_bar]
  end

  def test_every_style_of_every_bundled_set_is_safe
    OpenProject::Thematiq::Catalogue.bundled.sets.each { |token_set| assert_safe all_styles(token_set), token_set.id }
  end

  def test_hostile_values_never_reach_a_style
    TokenSet::KINDS.each_key do |key|
      HOSTILE_VALUES.each do |value|
        assert_safe all_styles(set(key => value)), "#{key} = #{value.inspect}"
      end
    end
  end

  def test_all_tokens_hostile_at_once
    hostile = TokenSet::KINDS.keys.to_h { |key| [key, 'red" onmouseover="alert(1); } body { display:none'] }

    assert_equal all_styles(TokenSet.fallback), all_styles(set(hostile))
  end

  def test_swatch
    assert_equal "background: #aa0055; border: 1px solid #{OpenProject::Thematiq::Tokens::Defaults::TOKENS['field']}",
                 Preview.new(set("primary" => "#aa0055")).swatch("primary")
  end
end
