# frozen_string_literal: true

require "test_helper"

# Primer drops its `test_selector:` argument in production, which is where the OpenProject image runs.
# A hook a test can find must be a plain data attribute: `data: { test_selector: "..." }` renders
# `data-test-selector` in every environment (first full test, finding 13).
class TestSelectorTest < Minitest::Test
  SOURCES = Dir[File.expand_path("../{app,lib}/**/*.{rb,erb}", __dir__)].sort

  def test_no_template_passes_primers_test_selector_argument
    offenders = SOURCES.flat_map do |file|
      File.readlines(file).each_with_index.filter_map do |line, index|
        # Every test_selector must sit inside a data hash on its line.
        line.scan(/(\S+\s*)\btest_selector:/).flatten.reject { |before| before.include?("{") }
            .map { "#{File.basename(file)}:#{index + 1}" }.first
      end
    end

    assert_empty offenders, "use data: { test_selector: ... }, Primer drops test_selector: in production"
  end

  def test_the_three_banners_of_the_picker_have_a_plain_hook
    show = File.read(File.expand_path("../app/views/thematiq/admin/show.html.erb", __dir__))
    %w[thematiq-catalogue-error thematiq-rejected-banner thematiq-no-results].each do |hook|
      assert_includes show, %(data: { test_selector: "#{hook}" }), hook
    end
  end
end
