# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/css_comments"
require "open_project/thematiq/css_tokens"
require "open_project/thematiq/custom_css"

class CssCommentsTest < Minitest::Test
  CssComments = OpenProject::Thematiq::CssComments
  # Many comment openings and no close: a lazy /\*.*?\*/ pattern scans to the end from every one of them.
  UNCLOSED = "/*#{'a/*' * 50_000}"

  def elapsed
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  end

  def test_each_closed_comment_becomes_one_space
    assert_equal ":root { --a: 1px; }   .b { }", CssComments.strip(":root { --a: 1px; } /* one */ .b {/* two\n lines */}")
    assert_equal "a   b", CssComments.strip("a /*/ still a comment */ b")
    assert_equal "plain", CssComments.strip("plain")
    assert_equal "", CssComments.strip(nil)
  end

  def test_an_unclosed_comment_stays_for_the_parser_to_refuse
    assert_equal "a   b /* open", CssComments.strip("a /* x */ b /* open")
  end

  def test_text_around_comments_keeps_its_characters
    stripped = CssComments.strip("/* é */ .ü { --naam: 'ë'; }")
    assert_equal "  .ü { --naam: 'ë'; }", stripped
    assert_equal Encoding::UTF_8, stripped.encoding
    assert stripped.valid_encoding?
  end

  def test_many_unclosed_openings_are_read_in_linear_time
    assert_operator elapsed { CssComments.strip(UNCLOSED) }, :<, 1
  end

  def test_the_token_file_reader_refuses_them_in_linear_time
    seconds = elapsed do
      error = assert_raises(OpenProject::Thematiq::CssTokens::Refused) { OpenProject::Thematiq::CssTokens.declarations(UNCLOSED) }
      assert_equal "nothing_usable", error.code
    end
    assert_operator seconds, :<, 1
  end

  def test_the_custom_css_check_refuses_them_in_linear_time
    text = "/*#{'a/*' * 21_000}"
    assert_operator text.bytesize, :<=, OpenProject::Thematiq::CustomCss::MAX_BYTES
    seconds = elapsed { refute OpenProject::Thematiq::CustomCss.check(text).ok? }
    assert_operator seconds, :<, 1
  end
end
