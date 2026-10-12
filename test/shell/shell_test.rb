# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "open_project/thematiq/shell/core_guard"
require "open_project/thematiq/shell/logo"
require "open_project/thematiq/shell/nextcloud_apps"
require "open_project/thematiq/shell/project_menu"

class ShellTest < Minitest::Test
  Shell = OpenProject::Thematiq::Shell
  TokenSet = Struct.new(:logo_url, :logo_inverse_url)

  def test_guard_names_every_file_when_the_core_is_not_there
    Dir.mktmpdir do |root|
      assert_equal Shell::CoreGuard::FILES.keys, Shell::CoreGuard.changed_files(root)
    end
  end

  def test_guard_names_only_the_file_that_changed
    Dir.mktmpdir do |root|
      path = "lib/example.rb"
      FileUtils.mkdir_p(File.join(root, "lib"))
      File.write(File.join(root, path), "one\n")
      files = { path => Digest::SHA256.hexdigest("one\n") }

      assert_empty changed(files, root)
      File.write(File.join(root, path), "two\n")
      assert_equal [path], changed(files, root)
    end
  end

  def test_logo_prefers_the_inverse_logo
    css = Shell::Logo.css(TokenSet.new("https://cloud.example.org/logo.svg", "https://cloud.example.org/logo-white.svg"))

    assert_includes css, 'url("https://cloud.example.org/logo-white.svg")'
  end

  def test_logo_writes_no_rule_without_a_logo
    assert_equal "", Shell::Logo.css(TokenSet.new(nil, nil))
  end

  def test_logo_address_cannot_leave_the_css_string
    css = Shell::Logo.css(TokenSet.new('https://cloud.example.org/a"); } body { display: none } </style><script>', nil))

    refute_match(/[<>]/, css)
    assert_equal 2, css.count('"')
    assert_equal 1, css.count("}")
  end

  def test_nextcloud_address_loses_its_trailing_slash
    assert_equal "https://cloud.example.org", Shell::NextcloudApps.normalize("https://cloud.example.org/ ")
    assert_equal "https://cloud.example.org/apps/files/",
                 Shell::NextcloudApps.url_for(Shell::NextcloudApps::APPS.first, "https://cloud.example.org")
  end

  def test_no_nextcloud_address_without_http
    [nil, "", "   ", "javascript:alert(1)", "cloud.example.org", 'https://cloud.example.org/"onclick="x'].each do |value|
      assert_nil Shell::NextcloudApps.normalize(value), value.inspect
    end
  end

  def test_menu_items_fall_into_the_groups_of_the_design
    menu = Shell::ProjectMenu

    assert_equal :plan, menu.group_for(:work_packages)
    assert_equal :together, menu.group_for(:"wiki-project-handbook")
    assert_equal :bottom, menu.group_for(:settings)
    assert_nil menu.group_for(:an_item_of_another_plugin)
  end

  def test_project_initials
    assert_equal "NR", Shell::ProjectMenu.initials("Northwind rollout Lyon")
    assert_equal "D", Shell::ProjectMenu.initials("demo")
    assert_equal "2A", Shell::ProjectMenu.initials("(2026) audit")
    assert_equal "", Shell::ProjectMenu.initials(nil)
  end

  def test_every_guarded_part_names_files_with_a_checksum
    Shell::CoreGuard::PARTS.each_value do |paths|
      assert_empty paths - Shell::CoreGuard::FILES.keys
    end
    assert_equal Shell::CoreGuard::FILES.keys.sort, Shell::CoreGuard::PARTS.values.flatten.uniq.sort
  end

  private

  def changed(files, root)
    files.reject { |path, sum| Digest::SHA256.file(File.join(root, path)).hexdigest == sum }.keys
  end
end
