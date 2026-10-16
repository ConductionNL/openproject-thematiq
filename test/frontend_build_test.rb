# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "json"
require "tmpdir"
require "open_project/thematiq/frontend_build"

class FrontendBuildTest < Minitest::Test
  FrontendBuild = OpenProject::Thematiq::FrontendBuild
  ROOT = File.expand_path("..", __dir__)

  def with_plugin(stamp: nil)
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "frontend/module"))
      File.write(File.join(root, "frontend/module/main.ts"), "export class PluginModule {}\n")
      File.write(File.join(root, FrontendBuild::STAMP), stamp.respond_to?(:call) ? stamp.call(root) : stamp) if stamp
      yield root
    end
  end

  def stamp_for(root, version: OpenProject::Thematiq::VERSION)
    JSON.generate("plugin_version" => version, "module_digest" => FrontendBuild.module_digest(File.join(root, "frontend/module")))
  end

  def test_the_default_image_has_no_stamp
    with_plugin do |root|
      status = FrontendBuild.status(root:)
      assert_equal :absent, status.state
      refute status.linked?
    end
  end

  def test_a_stamp_of_these_sources_is_current
    with_plugin(stamp: ->(root) { stamp_for(root) }) do |root|
      status = FrontendBuild.status(root:)
      assert_equal :current, status.state
      assert status.linked?
      assert status.current?
    end
  end

  def test_changed_sources_after_the_build_are_stale
    with_plugin(stamp: ->(root) { stamp_for(root) }) do |root|
      File.write(File.join(root, "frontend/module/main.ts"), "export class PluginModule { changed = true; }\n")
      status = FrontendBuild.status(root:)
      assert_equal :stale, status.state
      assert status.linked?
      refute status.current?
    end
  end

  def test_another_plugin_version_is_stale
    with_plugin(stamp: ->(root) { stamp_for(root, version: "0.0.1") }) do |root|
      assert_equal :stale, FrontendBuild.status(root:).state
    end
  end

  def test_a_broken_stamp_counts_as_absent
    ["{", "[]", "{\"plugin_version\": \"1\"}"].each do |text|
      with_plugin(stamp: text) do |root|
        assert_equal :absent, FrontendBuild.status(root:).state, text
      end
    end
  end

  def test_the_module_ships_with_the_gem_and_exports_the_plugin_module
    assert_match(/export class PluginModule\b/, File.read(File.join(ROOT, "frontend/module/main.ts")))
    spec = Gem::Specification.load(File.join(ROOT, "openproject-thematiq.gemspec"))
    assert_includes spec.files.map { |path| path.delete_prefix("#{ROOT}/") }, "frontend/module/main.ts"
  end
end
