# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/scopes"

# The order of winning, as the owner decided it: module in project, project, module, parent project, instance.
class ScopesTest < Minitest::Test
  Scopes = OpenProject::Thematiq::Scopes
  Row = Scopes::Row

  def row(project_id, module_name, id)
    Row.new(project_id:, module_name:, design_system_id: id)
  end

  def resolve(rows, chain, module_name = nil, &)
    Scopes.resolve(rows:, chain:, module_name:, &)
  end

  ALL = [
    Row.new(project_id: 3, module_name: "meetings", design_system_id: "module-in-project"),
    Row.new(project_id: 3, module_name: "", design_system_id: "project"),
    Row.new(project_id: nil, module_name: "meetings", design_system_id: "module"),
    Row.new(project_id: 2, module_name: "", design_system_id: "parent"),
    Row.new(project_id: 1, module_name: "", design_system_id: "grandparent")
  ].freeze

  def test_the_order_of_winning_for_the_content
    chain = [3, 2, 1]

    assert_equal "module-in-project", resolve(ALL, chain, "meetings").content.first
    assert_equal "project", resolve(ALL[1..], chain, "meetings").content.first
    assert_equal "module", resolve(ALL[2..], chain, "meetings").content.first
    assert_equal "parent", resolve(ALL[3..], chain, "meetings").content.first
    assert_equal "grandparent", resolve(ALL[4..], chain, "meetings").content.first, "nearest parent first, then further up"
    assert_nil resolve([], chain, "meetings").content.first
    assert_equal :instance, resolve([], chain, "meetings").content.last.kind
  end

  def test_the_whole_page_follows_the_project_and_its_parents_never_a_module
    chain = [3, 2, 1]

    assert_equal "project", resolve(ALL, chain, "meetings").page.first
    assert_equal "parent", resolve(ALL.values_at(0, 2, 3), chain, "meetings").page.first
    assert_nil resolve(ALL.values_at(0, 2), chain, "meetings").page.first, "a module choice is the content's only"
  end

  def test_a_module_choice_splits_the_page_from_its_content
    resolution = resolve(ALL.values_at(2, 3), [3, 2, 1], "meetings")

    assert_equal "parent", resolution.page.first
    assert_equal "module", resolution.content.first
    assert resolution.split?
    refute resolve(ALL, [3, 2, 1], "work_packages").split?
  end

  def test_outside_a_project_only_a_module_and_the_instance_count
    assert_equal "module", resolve(ALL, [], "meetings").content.first
    assert_nil resolve(ALL, [], "meetings").page.first
    assert_nil resolve(ALL, [], nil).content.first
  end

  def test_a_subproject_inherits_from_the_start
    resolution = resolve([row(1, "", "programme")], [7, 4, 1])

    assert_equal "programme", resolution.page.first
    assert_equal :parent, resolution.page.last.kind
    assert_equal 1, resolution.page.last.project_id
  end

  def test_a_row_naming_a_design_system_that_is_gone_is_passed_over
    resolution = resolve([row(3, "", "deleted"), row(2, "", "parent")], [3, 2]) { |id| id != "deleted" }

    assert_equal "parent", resolution.page.first
  end

  def test_the_source_says_where_the_choice_came_from
    assert_equal :module_in_project, resolve(ALL, [3, 2, 1], "meetings").content.last.kind
    assert_equal :module, resolve(ALL[2..], [3, 2, 1], "meetings").content.last.kind
    assert_equal "meetings", resolve(ALL[2..], [3, 2, 1], "meetings").content.last.module_name
  end

  def test_the_module_of_a_page_comes_from_its_menu_item
    assert_equal "work_packages", Scopes.module_of(:work_packages)
    assert_equal "work_packages", Scopes.module_of("work_packages_query_select")
    assert_equal "wiki", Scopes.module_of("wiki-project-documentation")
    assert_equal "team_planners", Scopes.module_of(:team_planner_view)
    assert_nil Scopes.module_of(:members)
    assert_nil Scopes.module_of(nil)
    Scopes::MODULES.each_key { |name| assert_match Scopes::MODULE_NAME, name }
  end
end

class ScopeRulesStoreTest < Minitest::Test
  def store(data = {})
    OpenProject::Thematiq::Store.new(backend: MemoryBackend.new(data))
  end

  def test_projects_may_not_choose_by_default_and_may_choose_every_set_when_the_list_is_empty
    s = store

    refute s.projects_may_choose?
    assert_empty s.project_choices
    assert_equal s.all_sets.map(&:id), s.sets_for_projects.map(&:id)
  end

  def test_the_rules_are_stored_and_the_list_limits_the_choice
    s = store

    assert s.save_project_rules(allow: true, choices: ["zuiddrecht", "", "cunningham", "zuiddrecht"])
    assert s.projects_may_choose?
    assert_equal %w[zuiddrecht cunningham], s.project_choices
    assert_equal %w[cunningham zuiddrecht], s.sets_for_projects.map(&:id).sort
  end

  def test_an_unknown_design_system_refuses_the_rules
    s = store

    refute s.save_project_rules(allow: true, choices: %w[zuiddrecht made-up])
    refute s.projects_may_choose?
    refute s.save_project_rules(allow: true, choices: ["<script>"])
  end

  def test_find_set_finds_a_custom_or_a_catalogue_set_and_nothing_else
    s = store

    assert_equal "zuiddrecht", s.find_set("zuiddrecht").id
    assert_nil s.find_set("")
    assert_nil s.find_set(nil)
    assert_nil s.find_set("made-up")
  end
end

# A module's design system reaches the content area only: the same variables, written on OpenProject's main element.
class ContentLayerTest < Minitest::Test
  Generator = OpenProject::Thematiq::Variables::Generator

  def test_every_block_of_the_content_variant_sits_on_the_content_element
    token_set = OpenProject::Thematiq::Catalogue.bundled.find("zuiddrecht")
    css = Generator.new(token_set, content: true).css
    selectors = css.scan(/^([^\n{}\/]+) \{$/).flatten

    refute_empty selectors
    selectors.each { |selector| assert selector.end_with?(Generator::CONTENT), selector }
    assert_includes selectors, Generator::CONTENT, ":root becomes the content element itself"
    assert_includes css, "--thematiq-primary: #3669a5;"
  end

  def test_the_content_variant_has_no_menu_block
    token_set = OpenProject::Thematiq::Tokens::TokenSet.from_set({ "id" => "m", "name" => "M", "tokens" => { "menu" => "#102030" } })

    assert_includes Generator.new(token_set).css, "#main-menu {"
    refute_includes Generator.new(token_set, content: true).css, "#main-menu"
  end

  def test_the_page_variant_is_unchanged
    token_set = OpenProject::Thematiq::Catalogue.bundled.find("zuiddrecht")

    refute_includes Generator.new(token_set).css, Generator::CONTENT
  end
end
