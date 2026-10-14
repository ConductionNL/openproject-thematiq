# frozen_string_literal: true

require "test_helper"
require "yaml"
require "open_project/thematiq/shell/core_guard"
require "open_project/thematiq/shell/nextcloud_apps"
require "open_project/thematiq/shell/app_row"
require "open_project/thematiq/shell/app_switcher"

# The list under the nine-dot button. It renders in a running OpenProject only, so these tests hold the parts
# that do not need one: the guard, the texts, the script and the wiring.
class AppSwitcherTest < Minitest::Test
  Shell = OpenProject::Thematiq::Shell
  ROOT = File.expand_path("../..", __dir__)
  EN = YAML.load_file(File.join(ROOT, "config/locales/en.yml")).dig("en", "thematiq", "shell", "app_switcher")
  SCRIPT = File.read(Shell::AppSwitcher::SCRIPT_PATH)

  def test_the_core_file_it_replaces_a_method_of_is_guarded_with_the_top_bar
    assert_includes Shell::CoreGuard::PARTS.fetch(:top_bar), "lib/redmine/menu_manager/top_menu/module_menu.rb"
    shell = File.read(File.join(ROOT, "lib/open_project/thematiq/shell.rb"))
    assert_match(/top_bar: \[TopBar, AppSwitcher, AccountMenu\]/, shell, "installed only when the top bar's core files are the known ones")
  end

  def test_every_entry_the_field_offers_has_a_second_line
    Shell::AppRow::KNOWN.each { |key| assert_kind_of String, EN.dig("lines", key), key }
  end

  def test_the_button_and_the_heading_say_all_apps_and_modules
    assert_equal "All apps and modules", EN["title"]
    source = File.read(File.join(ROOT, "lib/open_project/thematiq/shell/app_switcher.rb"))
    assert_includes source, %("aria-expanded": "false")
    assert_includes source, %("aria-label": t("thematiq.shell.app_switcher.title"))
    assert_includes source, "User.current.admin?", "Manage apps only for an administrator"
    assert_includes source, "call_hook(:module_menu_dialog_content_before)", "other plugins still add to the dialog"
  end

  def test_the_hook_column_steps_aside_for_the_plugins_list
    partial = File.read(File.join(ROOT, "app/views/thematiq/shell/_app_switcher_nextcloud.html.erb"))
    assert_includes partial, "AppSwitcher.installed?"
  end

  def test_the_script_cannot_close_its_tag_and_reaches_nowhere
    refute_match(%r{</script|<!--}i, SCRIPT)
    refute_match(/fetch\(|XMLHttpRequest|WebSocket|EventSource|sendBeacon|import\(|eval\(|new Function|innerHTML|outerHTML|document\.write|localStorage|cookie/, SCRIPT)
    assert_includes SCRIPT, Shell::AppSwitcher::DIALOG_ID
    assert_includes SCRIPT, "aria-expanded"
  end
end
