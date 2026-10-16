# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "open_project/thematiq/shell/core_guard"
require "open_project/thematiq/shell/logo"
require "open_project/thematiq/shell/nextcloud_apps"
require "open_project/thematiq/shell/app_row"
require "open_project/thematiq/shell/project_menu"
require "open_project/thematiq/shell/home"

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

  def test_logo_prefers_the_logo_for_dark_backgrounds_on_a_coloured_bar
    css = Shell::Logo.css(OpenProject::Thematiq::Catalogue.bundled.find("dinkelland"))
    token_set = OpenProject::Thematiq::Catalogue.bundled.find("zuiddrecht")
    blue = OpenProject::Thematiq::Tokens::TokenSet.from_set(token_set.to_set.merge("vocabulary" => {}))

    assert_includes Shell::Logo.css(blue), %(.op-app-header .op-logo .op-logo--link:not(.op-logo--link_high_contrast) { background-image: url("/thematiq/logos/zuiddrecht-dark.svg"); })
    refute_empty css
  end

  # The dossiq bar: Zuiddrecht's header colour is white, so the bar gets the plain logo, and the brand block and the
  # narrow screen get the emblem. The dark theme's bar is light blue (first full test, finding 12), also the plain logo.
  def test_logo_on_a_light_bar_is_the_plain_logo
    css = Shell::Logo.css(OpenProject::Thematiq::Catalogue.bundled.find("zuiddrecht")).lines.map(&:strip)

    assert_equal [
      %(.op-app-header .op-logo .op-logo--link:not(.op-logo--link_high_contrast) { background-image: url("/thematiq/logos/zuiddrecht.svg"); }),
      %(.op-app-header .op-app-menu .op-logo.thematiq-brand--has-emblem .op-logo--link { background-image: url("/thematiq/logos/zuiddrecht-emblem.svg"); }),
      %(.op-app-header .op-logo .op-logo--link.op-logo--link_high_contrast { background-image: url("/thematiq/logos/zuiddrecht.svg"); }),
      %(.op-app-header .op-logo--icon.op-logo--link { background-image: url("/thematiq/logos/zuiddrecht-emblem.svg"); })
    ], css
  end

  def test_only_a_bundled_logo_with_an_emblem_file_has_an_emblem
    assert_equal "/thematiq/logos/zuiddrecht-emblem.svg", Shell::Logo.emblem_url(OpenProject::Thematiq::Catalogue.bundled.find("zuiddrecht"))
    assert_nil Shell::Logo.emblem_url(OpenProject::Thematiq::Catalogue.bundled.find("dinkelland"))
    assert_nil Shell::Logo.emblem_url(OpenProject::Thematiq::Catalogue.bundled.find("amsterdam"))
  end

  def test_a_dark_bar_in_the_dark_theme_keeps_the_logo_for_dark_backgrounds
    token_set = OpenProject::Thematiq::Catalogue.bundled.find("zuiddrecht")
    dark = token_set.to_set.merge("dark" => { "tokens" => token_set.dark_tokens.merge("primary" => "#1b2a3d") })
    css = Shell::Logo.css(OpenProject::Thematiq::Tokens::TokenSet.from_set(dark))

    assert_includes css, %(body[data-color-mode="dark"][data-dark-theme="dark"] .op-app-header .op-logo .op-logo--link:not(.op-logo--link_high_contrast) { background-image: url("/thematiq/logos/zuiddrecht-dark.svg"); }),
                    "the white bar has the plain logo, the dark bar its own rule"
  end

  def test_every_bundled_logo_on_a_light_bar_reads_on_it
    OpenProject::Thematiq::Catalogue.bundled.sets.each do |token_set|
      css = Shell::Logo.css(token_set)
      next if css.empty?

      high_contrast = css.lines.find { |line| line.include?("op-logo--link_high_contrast {") }
      refute_match(/-dark\.svg/, high_contrast.to_s, "#{token_set.id}: the pale high contrast bar gets the plain logo")
    end
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

      css.lines.each do |line|
        assert_match(%r{\A(?:(?:body\[data-color-mode="dark"\]\[data-dark-theme="dark"\] )?\.op-app-header \.op-logo \.op-logo--link(?::not\(\.op-logo--link_high_contrast\)|\.op-logo--link_high_contrast)|\.op-app-header \.op-app-menu \.op-logo\.thematiq-brand--has-emblem \.op-logo--link|\.op-app-header \.op-logo--icon\.op-logo--link) \{ background-image: url\("/thematiq/logos/[a-z0-9-]+\.svg"\); \}\n?\z}, line, token_set.id)
      end
    end
  end

  def test_nextcloud_address_loses_its_trailing_slash
    assert_equal "https://cloud.example.org", Shell::NextcloudApps.normalize("https://cloud.example.org/ ")
    assert_equal "https://cloud.example.org/apps/files/",
                 Shell::NextcloudApps.url_for(Shell::NextcloudApps::APPS.first, "https://cloud.example.org")
  end

  def test_a_long_run_of_slashes_is_read_in_linear_time
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    assert_nil Shell::NextcloudApps.normalize("#{'/' * 50_000}x")
    assert_equal "https://cloud.example.org", Shell::NextcloudApps.normalize("https://cloud.example.org#{'/' * 50_000}")
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 1
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

  def test_app_row_setting
    row = Shell::AppRow

    assert_equal row::DEFAULT, row.wanted(nil)
    assert_equal row::DEFAULT, row.wanted("  ")
    assert_equal row::DEFAULT, row.wanted("<script>")
    assert_empty row.wanted("none")
    assert_equal %w[files gantt], row.wanted("Files, gantt , files")
    assert_equal 12, row.wanted((1..40).map { |n| "m#{n}" }.join(",")).size
  end

  def test_app_row_leaves_out_what_the_user_cannot_open_and_fills_up
    row = Shell::AppRow
    modules = %w[home my_page projects work_packages gantt boards meetings news]

    assert_equal %w[files mail calendar work_packages boards gantt meetings],
                 row.pick(row::OPHEADER, %w[files mail calendar tasks talk contacts] + modules)
    assert_equal %w[work_packages boards gantt meetings home my_page projects], row.pick(row::OPHEADER, modules)
    assert_equal %w[home], row.pick(row::OPHEADER, %w[home])
    assert_empty row.pick(row::DEFAULT, modules), "the dossiq bar has no tiles"
    assert_empty row.pick([], modules)
  end

  def test_app_row_gives_the_last_place_to_a_current_entry_outside_it
    row = Shell::AppRow
    modules = %w[home my_page projects work_packages gantt boards meetings news]

    assert_equal %w[work_packages boards news], row.pick(%w[work_packages boards gantt], modules, "news")
    assert_equal %w[work_packages boards gantt], row.pick(%w[work_packages boards gantt], modules, "boards")
    assert_equal %w[work_packages boards gantt], row.pick(%w[work_packages boards gantt], modules, "members")
  end

  def test_app_row_knows_the_global_module_of_a_project_page
    assert_equal "team_planners", Shell::AppRow.current_key(:team_planner_view)
    assert_equal "work_packages", Shell::AppRow.current_key(:work_packages)
    assert_equal "", Shell::AppRow.current_key(nil)
  end

  def test_home_keeps_every_block_but_the_welcome_text
    blocks = [{ name: "welcome", if: -> { true } }, { name: "news" }, { name: "administration", if: -> { false } }]
    home = Shell::Home

    assert_equal %w[news administration], home.other_blocks({ blocks: }).fetch(:blocks).map { |block| block[:name] }
    assert home.welcome?({ blocks: })
    refute home.welcome?({ blocks: [{ name: "welcome", if: -> { false } }] })
    refute home.welcome?({ blocks: [{ name: "news" }] })
    assert_empty home.other_blocks({}).fetch(:blocks)
  end

  def test_the_menu_script_cannot_close_its_script_tag
    script = Shell::ProjectMenu.script

    refute_empty script
    refute_match(%r{</script}i, script)
    refute_includes script, "<!--"
  end

  def test_the_nested_menu_only_applies_while_the_overrides_are_on
    css = File.read(File.expand_path("../../stylesheets/shell/30-nested-menu.css", __dir__)).gsub(%r{/\*.*?\*/}m, "")
    selectors = css.gsub(/@media[^{]*\{/, "").scan(/([^{}]+)\{/).flatten.flat_map { |list| split_selectors(list) }

    refute_empty selectors
    selectors.each { |selector| assert_includes selector, "#main-menu:has(.thematiq-project--initials)", selector }
  end

  private

  # Splits a selector list on its commas, leaving the commas inside :is() and :has() alone.
  def split_selectors(list)
    depth = 0
    list.each_char.slice_when { |char, _| depth += { "(" => 1, ")" => -1 }.fetch(char, 0); char == "," && depth.zero? }
        .map { |chars| chars.join.delete_suffix(",").strip }.reject(&:empty?)
  end

  def changed(files, root)
    files.reject { |path, sum| Digest::SHA256.file(File.join(root, path)).hexdigest == sum }.keys
  end
end
