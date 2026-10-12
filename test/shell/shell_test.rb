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

  def test_logo_prefers_the_logo_for_dark_backgrounds
    css = Shell::Logo.css(OpenProject::Thematiq::Catalogue.bundled.find("zuiddrecht"))

    assert_equal %(.op-app-header .op-logo .op-logo--link { background-image: url("/thematiq/logos/zuiddrecht-dark.svg"); }), css
  end

  def test_logo_takes_the_normal_logo_when_there_is_no_other_and_respects_the_mount_path
    css = Shell::Logo.css(OpenProject::Thematiq::Catalogue.bundled.find("dinkelland"), root: "/op")

    assert_includes css, 'url("/op/thematiq/logos/dinkelland.svg")'
  end

  def test_logo_writes_no_rule_without_a_bundled_logo
    assert_equal "", Shell::Logo.css(OpenProject::Thematiq::Catalogue.bundled.find("amsterdam"))
    assert_equal "", Shell::Logo.css(OpenProject::Thematiq::Catalogue.bundled.find("cunningham"))
    assert_equal "", Shell::Logo.rule(nil)
  end

  def test_logo_address_cannot_leave_the_css_string
    css = Shell::Logo.rule('https://cloud.example.org/a"); } body { display: none } </style><script>')

    refute_match(/[<>]/, css)
    assert_equal 2, css.count('"')
    assert_equal 1, css.count("}")
  end

  def test_every_bundled_set_gives_a_plain_logo_rule_or_none
    OpenProject::Thematiq::Catalogue.bundled.sets.each do |token_set|
      css = Shell::Logo.css(token_set)

      assert_match(%r{\A(?:|\.op-app-header \.op-logo \.op-logo--link \{ background-image: url\("/thematiq/logos/[a-z0-9-]+\.svg"\); \})\z}, css, token_set.id)
    end
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
