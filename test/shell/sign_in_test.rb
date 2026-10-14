# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/assets"
require "open_project/thematiq/shell/logo"
require "open_project/thematiq/shell/sign_in"

# The sign-in page as Nextcloud Zuiddrecht draws it. It renders in a running OpenProject only, so these tests hold
# what does not need one: what the page shows per design system, the wiring and the stylesheet's reach.
class SignInTest < Minitest::Test
  Shell = OpenProject::Thematiq::Shell
  ROOT = File.expand_path("../..", __dir__)

  def test_an_organisation_with_an_emblem_is_named_and_shown
    view = Shell::SignIn.view(OpenProject::Thematiq::Catalogue.bundled.find("zuiddrecht"))

    assert_equal "/thematiq/logos/zuiddrecht.svg", view[:logo], "the plain logo, for the light ground"
    assert_equal "/thematiq/logos/zuiddrecht-emblem.svg", view[:watermark]
    assert_equal "Gemeente Zuiddrecht", view[:organisation]
  end

  def test_a_set_without_an_emblem_names_no_organisation
    view = Shell::SignIn.view(OpenProject::Thematiq::Catalogue.bundled.find("cunningham"))

    assert_nil view[:organisation]
    assert_nil view[:watermark]
  end

  def test_the_hooks_of_cores_login_view_render_the_parts
    hooks = File.read(File.join(ROOT, "lib/open_project/thematiq/hooks.rb"))

    assert_includes hooks, %(render_on :view_account_login_top, partial: "thematiq/shell/sign_in_top")
    assert_includes hooks, %(render_on :view_account_login_bottom, partial: "thematiq/shell/sign_in_bottom")
    assert_includes File.read(File.join(ROOT, "app/views/thematiq/shell/_sign_in_bottom.html.erb")), "nonced_javascript_tag"
  end

  # The bar is hidden on the pages of the account controller only, never on the rest of OpenProject.
  def test_the_stylesheet_hides_the_bar_on_the_account_pages_only
    css = File.read(File.join(ROOT, "stylesheets/shell/45-sign-in.css")).gsub(%r{/\*.*?\*/}m, "")
    css.scan(/([^{}]+)\{/).flatten.flat_map { |selectors| selectors.split(",") }.map(&:strip).reject(&:empty?).each do |selector|
      next if selector.start_with?("@media", ".thematiq-sign-in", "#login-form")

      assert selector.start_with?("body.controller-account"), selector
    end
  end

  def test_the_script_only_moves_the_lead
    script = File.read(Shell::SignIn::SCRIPT_PATH)

    assert_includes script, "data-thematiq-sign-in-lead"
    refute_match(/innerHTML|fetch\(|XMLHttpRequest/, script)
  end
end
