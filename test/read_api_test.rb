# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/read_api"

class ReadApiTest < Minitest::Test
  ReadApi = OpenProject::Thematiq::ReadApi

  def zuiddrecht
    OpenProject::Thematiq::Catalogue.bundled.find("zuiddrecht")
  end

  def test_shell_tokens_has_thematiqs_shape_and_all_eighteen_roles
    answer = ReadApi.shell_tokens(zuiddrecht, logo_urls: ["https://op.example/thematiq/logos/z.svg", nil])

    assert_equal %w[version id name revision tokens logo], answer.keys
    assert_equal 1, answer["version"]
    assert_equal OpenProject::Thematiq::Tokens::TokenSet::KINDS.keys, answer["tokens"].keys
    assert(answer["tokens"].values.all? { |value| value.is_a?(String) && !value.empty? })
    assert_equal({ "url" => "https://op.example/thematiq/logos/z.svg", "inverse_url" => nil }, answer["logo"])
    assert_match(/\A\h{16}\z/, answer["revision"])
  end

  def test_the_revision_changes_only_when_a_value_changes
    same = ReadApi.shell_tokens(zuiddrecht)["revision"]

    assert_equal same, ReadApi.shell_tokens(zuiddrecht)["revision"]
    refute_equal same, ReadApi.shell_tokens(OpenProject::Thematiq::Catalogue.bundled.default)["revision"]
    refute_equal same, ReadApi.shell_tokens(zuiddrecht, logo_urls: ["https://x/y.svg", nil])["revision"]
  end

  def test_the_contrast_check
    assert_equal "pass", ReadApi.contrast("#000000", "#ffffff")["verdict"]
    assert_equal 21.0, ReadApi.contrast("black", "white")["ratio"].round(1) if ReadApi.contrast("black", "white")["ratio"]
    assert_equal "large_text_only", ReadApi.contrast("#888888", "#ffffff")["verdict"]
    assert_equal "fail", ReadApi.contrast("#cccccc", "#ffffff")["verdict"]
    HOSTILE_VALUES.each do |value|
      answer = ReadApi.contrast(value, "#ffffff")
      assert_includes %w[unknown pass fail large_text_only], answer["verdict"], value.inspect
      assert_nil answer["foreground"] unless OpenProject::Thematiq::Tokens::Validator.color(value.to_s)
    end
  end

  def test_a_summary_names_the_active_one
    row = ReadApi.summary(zuiddrecht, active_id: "zuiddrecht", custom: false)

    assert row["active"]
    assert_equal zuiddrecht["primary"], row["primary"]
  end
end
