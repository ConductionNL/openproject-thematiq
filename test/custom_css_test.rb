# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/custom_css"

class CustomCssTest < Minitest::Test
  CustomCss = OpenProject::Thematiq::CustomCss

  def test_rules_and_media_are_written_anew
    result = CustomCss.check(<<~CSS)
      /* our own touch */
      .op-app-header   { border-bottom : 3px solid #c8102e ; }
      a:hover, a:focus-visible { text-decoration: underline !important; }
      @media (max-width: 680px) { .op-sidebar { width: calc(100% - 16px); } }
      :root { --org-gap: 12px; }
    CSS

    assert result.ok?, result.errors.inspect
    assert_equal <<~CSS.strip, result.css
      .op-app-header { border-bottom: 3px solid #c8102e; }
      a:hover, a:focus-visible { text-decoration: underline !important; }
      @media (max-width: 680px) {
        .op-sidebar { width: calc(100% - 16px); }
      }
      :root { --org-gap: 12px; }
    CSS
  end

  def test_empty_is_fine_and_clears
    assert CustomCss.check("  ").ok?
    assert_equal "", CustomCss.check("").css
  end

  ATTACKS = {
    "@import url(https://evil.example/x.css);" => "stray_text",
    "@font-face { font-family: x; src: url(x.woff); }" => "at_rule",
    "body { background: url(javascript:alert(1)); }" => "value",
    "body { background-image: url('https://tracker.example/p.png'); }" => "value",
    "body { width: expression(alert(1)); }" => "value",
    "body { behavior: url(x.htc); }" => "property",
    "body { -moz-binding: url(x.xml#y); }" => "property",
    "</style><script>alert(1)</script>" => "markup",
    "body { color: red; } </style><script>alert(1)</script>" => "markup",
    "body { content: '\\3c script'; }" => "escape",
    "body { color: red" => "unclosed",
    "body { a { color: red } }" => "nested_block",
    "@media screen { @media print { a { color: red } } }" => "nested_at_rule",
    "body { content: \"unclosed; }" => "value",
    "body { color: attr(data-x); }" => "value",
    "body { background: image-set('x.png' 1x); }" => "value",
    "@charset \"utf-8\"; a { color: red; }" => "selector",
    "body { color: red; } stray" => "stray_text",
    "body{}x{}{}" => "selector"
  }.freeze

  def test_every_attack_refuses_the_whole_submission
    ATTACKS.each do |css, code|
      result = CustomCss.check(css)

      refute result.ok?, css
      assert_nil result.css, css
      assert_includes result.errors.map(&:first), code, "#{css} => #{result.errors.inspect}"
    end
  end

  def test_limits
    refute CustomCss.check("a { color: red; }" * 5000).ok?
    assert_equal [["too_large", ""]], CustomCss.check("a { color: red; }\n" * 4000).errors
  end

  def test_the_output_can_never_close_its_style_tag
    ["a { content: '</style>'; }", "a[title='</style>'] { color: red; }"].each do |css|
      result = CustomCss.check(css)
      refute result.ok?, css
    end
  end
end
