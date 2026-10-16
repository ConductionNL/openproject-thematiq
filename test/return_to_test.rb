# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/return_to"

class ReturnToTest < Minitest::Test
  ReturnTo = OpenProject::Thematiq::ReturnTo
  NEXTCLOUD = "https://cloud.example.nl"

  def test_a_path_on_this_openproject_passes
    assert_equal "/", ReturnTo.path("/")
    assert_equal "/projects/demo/work_packages?query_id=3#top", ReturnTo.path("/projects/demo/work_packages?query_id=3#top")
  end

  def test_a_path_that_a_browser_reads_as_another_host_is_refused
    ["//evil.example", "/\\evil.example", "\\\\evil.example", "/\t/evil.example", "/\n/evil.example", "/\r/evil.example",
     " //evil.example", "/ /evil.example", "/\u0000/evil.example", "/ /evil.example"].each do |target|
      assert_nil ReturnTo.path(target), target.inspect
    end
  end

  def test_an_address_with_a_scheme_is_not_a_path
    ["https://evil.example/", "javascript:alert(1)", "data:text/html,<script>alert(1)</script>", "evil.example", ""].each do |target|
      assert_nil ReturnTo.path(target), target.inspect
    end
  end

  def test_markup_and_overlong_paths_are_refused
    assert_nil ReturnTo.path('/"><script>alert(1)</script>')
    assert_nil ReturnTo.path("/#{'a' * 500}")
    assert_nil ReturnTo.path(nil)
  end

  def test_an_address_under_the_nextcloud_address_passes
    assert_equal "#{NEXTCLOUD}/apps/files/", ReturnTo.nextcloud("#{NEXTCLOUD}/apps/files/", NEXTCLOUD)
    assert_equal "#{NEXTCLOUD}/apps/files/", ReturnTo.nextcloud("#{NEXTCLOUD}/apps/files/", "#{NEXTCLOUD}/")
  end

  def test_an_address_elsewhere_is_refused
    ["https://cloud.example.nl.evil.example/", "https://cloud.example.nl@evil.example/", "http://cloud.example.nl/apps/",
     "https://evil.example/?#{NEXTCLOUD}/", "#{NEXTCLOUD}/\t/x", "#{NEXTCLOUD}/\\x", "#{NEXTCLOUD}/\"><script>",
     "javascript:alert(1)//#{NEXTCLOUD}/", "#{NEXTCLOUD}/#{'a' * 500}"].each do |target|
      assert_nil ReturnTo.nextcloud(target, NEXTCLOUD), target.inspect
    end
  end

  def test_without_a_nextcloud_address_nothing_but_a_path_passes
    assert_nil ReturnTo.nextcloud("#{NEXTCLOUD}/apps/files/", nil)
    assert_nil ReturnTo.nextcloud("/apps/files/", "")
  end
end
