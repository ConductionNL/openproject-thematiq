# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/design_systems"

class DesignSystemsTest < Minitest::Test
  DesignSystems = OpenProject::Thematiq::DesignSystems

  def test_the_whole_design_systems_are_thematiqs
    assert_equal %w[cunningham high-contrast lasuite nldesign none summer-breeze], DesignSystems.ids.sort
    assert DesignSystems.known?("lasuite")
    refute DesignSystems.known?("../lasuite")
    refute DesignSystems.known?(nil)
  end

  def test_each_set_belongs_to_its_design_system
    assert_equal "lasuite", DesignSystems.for_set("frankendesk")
    assert_equal "high-contrast", DesignSystems.for_set("hoog-contrast")
    assert_equal "summer-breeze", DesignSystems.for_set("summer-breeze")
    assert_equal "nldesign", DesignSystems.for_set("utrecht"), "a thematiq set without one counts as NL Design System"
    assert_nil DesignSystems.for_set("openproject-default")
    assert_equal "lasuite", DesignSystems.for_set("custom-3", base_id: "lasuite")
  end
end
