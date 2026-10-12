# frozen_string_literal: true

require "test_helper"

class ValidatorTest < Minitest::Test
  V = OpenProject::Thematiq::Tokens::Validator

  def test_accepts_hex_colours
    assert_equal "#1a67a3", V.color("#1A67A3")
    assert_equal "#fff", V.color(" #fff ")
    assert_equal "#11223344", V.color("#11223344")
  end

  def test_accepts_named_colours
    assert_equal "rebeccapurple", V.color("RebeccaPurple")
    assert_equal "transparent", V.color("transparent")
  end

  def test_accepts_colour_functions
    assert_equal "rgb(26, 103, 163)", V.color("rgb(26, 103, 163)")
    assert_equal "rgba(255,255,255,.12)", V.color("rgba(255,255,255,.12)")
    assert_equal "rgb(26 103 163 / 50%)", V.color("rgb(26 103 163 / 50%)")
    assert_equal "hsl(210deg 72% 37%)", V.color("hsl(210deg 72% 37%)")
    assert_equal "oklch(0.5 0.1 250)", V.color("oklch(0.5 0.1 250)")
  end

  def test_refuses_hostile_colours
    HOSTILE_VALUES.each { |value| assert_nil V.color(value), "accepted colour #{value.inspect}" }
  end

  def test_refuses_unknown_words_and_broken_functions
    ["notacolor", "inherit", "rgb()", "rgb(1,2)", "rgb(1,2,3,4,5)", "rgb(a,b,c)", "rgb(1,2,3", "foo(1,2,3)",
     "rgb(1,2,3))", "rgb((1,2,3)"].each { |value| assert_nil V.color(value), "accepted colour #{value.inspect}" }
  end

  def test_accepts_lengths
    assert_equal "3px", V.length("3px")
    assert_equal "0", V.length("0")
    assert_equal "0.5rem", V.length("0.5REM")
    assert_equal "50%", V.length("50%")
  end

  def test_refuses_hostile_lengths
    (HOSTILE_VALUES + ["-3px", "3", "3 px", "3px 4px", "1e3px", "9999px", "3vw", "px"]).each do |value|
      assert_nil V.length(value), "accepted length #{value.inspect}"
    end
  end

  def test_accepts_font_stacks_and_normalises_quotes
    assert_equal "'Fira Sans', system-ui, sans-serif", V.font_family(%("Fira Sans", system-ui, sans-serif))
    assert_equal "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica Neue, Arial",
                 V.font_family("-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica Neue, Arial")
  end

  def test_refuses_hostile_font_stacks
    hostile = HOSTILE_VALUES + [
      "Arial; } body { display:none", "Arial, ", ",Arial", "'Fira Sans", "'Fira' Sans'", %('Fira"), "Arial}", "Arial{",
      "Arial\\", "Arial, url(x)", "Arial</style>", "'a;b'", "'a}b'", "Arial\nsans-serif", "x" * 401,
      (["Arial"] * 21).join(", "), "1Arial"
    ]
    hostile.each { |value| assert_nil V.font_family(value), "accepted font stack #{value.inspect}" }
  end

  def test_file_names
    assert_equal "zuiddrecht-inverse.svg", V.file_name("zuiddrecht-inverse.svg")
    assert_equal "logo_2.png", V.file_name("logo_2.png")
    assert_equal "zuiddrecht.svg", V.file_name("img/logos/zuiddrecht.svg"), "a generator path gives the file name only"
    ["../a.svg", "/a.svg", "a/../b.svg", "a//b.svg", "a\\b.svg", "a/b/c/d/e/f.svg", "A/b.svg", "a..svg", ".svg", "a.svg.exe",
     "a.SVG", "a b.svg", "a.svg\n", "a.gif", "https://x/a.svg", "", nil, 1].each do |value|
      assert_nil V.file_name(value), "accepted file name #{value.inspect}"
    end
  end

  def test_labels
    assert_equal "Gemeente Zuiddrecht", V.label(" Gemeente Zuiddrecht ")
    assert_equal "a b", V.label("a\nb")
    assert_nil V.label("")
    assert_nil V.label("x" * 121)
    assert_nil V.label(nil)
  end
end
