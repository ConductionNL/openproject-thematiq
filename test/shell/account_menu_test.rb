# frozen_string_literal: true

require "test_helper"
require "yaml"
require "open_project/thematiq/shell/account_menu"

# The account menu as a dropdown under the avatar. It renders in a running OpenProject only, so these tests hold the
# parts that do not need one: the guard, the texts, the script and the wiring.
class AccountMenuTest < Minitest::Test
  Shell = OpenProject::Thematiq::Shell
  ROOT = File.expand_path("../..", __dir__)
  EN = YAML.load_file(File.join(ROOT, "config/locales/en.yml")).dig("en", "thematiq", "shell", "account_menu")
  SCRIPT = File.read(Shell::AccountMenu::SCRIPT_PATH)
  SOURCE = File.read(File.join(ROOT, "lib/open_project/thematiq/shell/account_menu.rb"))
  PARTIAL = File.read(File.join(ROOT, "app/views/thematiq/shell/_account_menu.html.erb"))

  def test_installed_with_the_top_bar_only
    shell = File.read(File.join(ROOT, "lib/open_project/thematiq/shell.rb"))

    assert_match(/top_bar: \[TopBar, AppSwitcher, AccountMenu\]/, shell)
    assert_includes Shell::CoreGuard::PARTS[:top_bar], "lib/redmine/menu_manager/top_menu/user_menu.rb"
  end

  def test_signed_out_and_on_failure_core_renders
    assert_includes SOURCE, "return super unless User.current.logged?"
    assert_match(/rescue StandardError => e\n.*\n\s+super/, SOURCE)
  end

  # The entries are core's: the items core passes in, with core's address for each.
  def test_the_entries_are_cores
    assert_includes SOURCE, "allowed_node_url(item, nil)"
    assert_includes SOURCE, "item.caption"
    assert_includes SOURCE, "item.partial"
  end

  def test_a_disclosure_with_its_state_and_a_named_region
    assert_includes PARTIAL, %(aria-expanded="false")
    assert_includes PARTIAL, %(aria-controls="<%= panel_id %>")
    assert_includes PARTIAL, "<nav"
    assert_includes PARTIAL, %(popover="manual"), "in the top layer, so nothing on the page covers it"
    refute_includes PARTIAL, %(role="menu"), "links in a list, Tab keeps working"
    assert_equal %w[button region], EN.keys.sort
    assert_includes EN["button"], "%{name}"
  end

  def test_the_script_opens_on_click_and_hover_and_closes_on_escape
    assert_includes SCRIPT, "aria-expanded"
    assert_includes SCRIPT, %("Escape")
    assert_includes SCRIPT, "button.focus()"
    assert_includes SCRIPT, "mouseenter"
    assert_includes SCRIPT, "mouseleave"
    assert_includes SCRIPT, "focusout"
    refute_match(/innerHTML|fetch\(|XMLHttpRequest/, SCRIPT)
  end

  def test_the_script_is_on_the_page_when_installed
    body = File.read(File.join(ROOT, "app/views/thematiq/shell/_body_bottom.html.erb"))

    assert_includes body, "AccountMenu.installed?"
    assert_includes body, "AccountMenu.script"
  end
end
