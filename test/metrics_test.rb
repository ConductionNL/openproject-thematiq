# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/health"
require "open_project/thematiq/metrics"

class MetricsTest < Minitest::Test
  Metrics = OpenProject::Thematiq::Metrics

  def test_off_without_a_long_enough_token
    assert_nil Metrics.token({})
    assert_nil Metrics.token({ "THEMATIQ_METRICS_TOKEN" => "short" })
    assert_equal "x" * 24, Metrics.token({ "THEMATIQ_METRICS_TOKEN" => "x" * 24 })
  end

  def health
    store = OpenProject::Thematiq::Store.new(backend: MemoryBackend.new, env: {})
    OpenProject::Thematiq::Health.report(store:, tables: { "uploads" => true, "scopes" => true, "changes" => true }, core_changed: [])
  end

  def test_the_text_format
    text = Metrics.text(health:, counts: { "scopes" => 2, "changes" => 7 })

    assert_includes text, "# TYPE thematiq_up gauge\nthematiq_up 1\n"
    assert_includes text, "thematiq_changes 7"
    assert_includes text, "thematiq_scopes 2"
    assert_match(/^thematiq_info\{version="#{Regexp.escape(OpenProject::Thematiq::VERSION)}",active="cunningham",from_environment="false"\} 1$/, text)
    text.each_line { |line| assert_match(/\A(?:# (?:HELP|TYPE) thematiq_\w+ .+|thematiq_\w+(?:\{[^}]*\})? \d+)\n\z/, line) }
  end

  def test_a_label_cannot_break_the_format
    assert_equal 'a\\"b\\nc', Metrics.escape("a\"b\nc")
    assert_equal 'a\\\\b', Metrics.escape("a\\b")
    assert_equal 'a\\\\\\"', Metrics.escape('a\\"')
  end
end
