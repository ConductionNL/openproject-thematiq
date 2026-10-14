# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/email"

class EmailTest < Minitest::Test
  Email = OpenProject::Thematiq::Email

  def set
    OpenProject::Thematiq::Catalogue.bundled.find("zuiddrecht")
  end

  def test_the_header_is_inline_and_escapes_the_title
    html = Email.header_html(set, title: "<b>Town</b> & co", logo_url: "https://op.example/thematiq/logos/z.svg?x=\"y\"")

    assert_includes html, "background: #{set['primary']};"
    assert_includes html, "&lt;b&gt;Town&lt;/b&gt; &amp; co"
    assert_includes html, 'src="https://op.example/thematiq/logos/z.svg?x=&quot;y&quot;"'
    refute_includes html, "<style"
  end

  def test_the_footer_keeps_lines_escapes_text_and_lists_links
    html = Email.footer_html(set, text: "Gemeente Zuiddrecht\nPostbus 1 <script>", links: { "privacy" => "https://example.org/p" },
                                  labels: { "privacy" => "Privacy statement" })

    assert_includes html, "Gemeente Zuiddrecht<br>Postbus 1 &lt;script&gt;"
    assert_includes html, '<a href="https://example.org/p"'
    assert_equal "", Email.footer_html(set, text: " ", links: {}, labels: {})
  end

  def test_the_store_keeps_plain_text_only
    store = OpenProject::Thematiq::Store.new(backend: MemoryBackend.new, env: {})
    refute store.email_styled?
    assert store.save_email_settings(styled: true, footer: "Line one\r\nLine two")
    assert_equal "Line one\nLine two", store.email_footer
    refute store.save_email_settings(styled: true, footer: "<b>x</b>")
    refute store.save_email_settings(styled: true, footer: "x" * (Email::MAX_FOOTER + 1))
  end
end
