# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq"

class SurfacesTest < Minitest::Test
  Thematiq = OpenProject::Thematiq
  Generator = Thematiq::Variables::Generator

  def stripe_set(vocabulary)
    Thematiq::Tokens::TokenSet.from_set({ "id" => "s", "name" => "S", "tokens" => {}, "vocabulary" => vocabulary })
  end

  def test_a_brand_stripe_from_three_colours_in_their_ratios
    css = Generator.new(stripe_set("brand-stripe-color-1" => "#2f6b4a", "brand-stripe-color-2" => "#f5b82e", "brand-stripe-color-3" => "#2f6b4a",
                                   "brand-stripe-ratio-1" => "3", "brand-stripe-ratio-2" => "1", "brand-stripe-ratio-3" => "3",
                                   "brand-stripe-height" => "6px")).css

    assert_includes css, "--thematiq-v-brand-stripe: linear-gradient(to right, #2f6b4a 0 42.86%, #f5b82e 42.86% 57.14%, #2f6b4a 57.14% 100%);"
    assert_includes css, "--thematiq-v-brand-stripe-height: 6px;"
  end

  def test_no_stripe_without_all_three_colours
    refute_includes Generator.new(stripe_set("brand-stripe-color-1" => "#2f6b4a")).css, "--thematiq-v-brand-stripe"
  end

  def test_footer_links_only_take_web_addresses
    store = Thematiq::Store.new(backend: MemoryBackend.new, env: {})
    assert store.save_footer_links("privacy" => "https://example.org/privacy", "imprint" => "", "accessibility" => "http://example.org/a11y")
    assert_equal({ "privacy" => "https://example.org/privacy", "accessibility" => "http://example.org/a11y" }, store.footer_links)
    ["javascript:alert(1)", "data:text/html,x", "//evil.example", "ftp://x", "https://#{'a' * 500}.org"].each do |address|
      refute store.save_footer_links("privacy" => address), address
    end
    assert_equal 2, store.footer_links.size, "a refused save keeps the links of before"
  end

  def test_the_sign_in_background_rule
    Thematiq::Assets.upload_source = lambda do |_set_id|
      [Thematiq::Uploads::Record.build(token: "b" * 64, set_id: "custom", kind: "login_background", format: "jpeg", byte_size: 10, sha256: "0f" * 32)]
    end
    custom = Thematiq::Tokens::TokenSet.from_set({ "id" => "custom", "name" => "C", "tokens" => {} })

    assert_equal "body.controller-account { background: url(/thematiq/files/#{'b' * 64}) center / cover no-repeat fixed; }",
                 Thematiq::Assets.bundled.login_background_css(custom)
    assert_equal "", Thematiq::Assets.bundled.login_background_css(Thematiq::Catalogue.bundled.default)
  ensure
    Thematiq::Assets.upload_source = nil
  end
end
