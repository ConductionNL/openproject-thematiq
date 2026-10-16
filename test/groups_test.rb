# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/page_scope"

class GroupsTest < Minitest::Test
  Store = OpenProject::Thematiq::Store
  PageScope = OpenProject::Thematiq::PageScope

  Groups = Struct.new(:ids) do
    def pluck(_column) = ids
  end
  Person = Struct.new(:logged, :group_ids) do
    def logged? = logged
    def groups = Groups.new(group_ids)
  end

  def store
    @store ||= Store.new(backend: MemoryBackend.new("active_id" => "cunningham"), env: {})
  end

  def with_user(user)
    yield user
  end

  def test_the_first_group_of_a_person_decides
    assert store.save_group_choices([["7", "zuiddrecht"], ["9", "amsterdam"], ["", ""]])
    with_user(Person.new(true, [9, 7])) { |user| assert_equal "zuiddrecht", PageScope.group_set(store, user).id }
    with_user(Person.new(true, [9])) { |user| assert_equal "amsterdam", PageScope.group_set(store, user).id }
    with_user(Person.new(true, [3])) { |user| assert_nil PageScope.group_set(store, user) }
    with_user(Person.new(false, [7])) { |user| assert_nil PageScope.group_set(store, user), "the sign-in page has no person" }
  end

  def test_the_rules
    refute store.save_group_choices([["7", "nope"]])
    refute store.save_group_choices([["x; drop", "zuiddrecht"]])
    assert store.save_group_choices([["7", "zuiddrecht"], ["7", "amsterdam"]])
    assert_equal 1, store.group_choices.size, "a group is listed once, the first place counts"
  end
end
