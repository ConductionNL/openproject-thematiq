# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "open_project/thematiq/bundle"
require "open_project/thematiq/boot_bundle"

class BootBundleTest < Minitest::Test
  BootBundle = OpenProject::Thematiq::BootBundle
  Bundle = OpenProject::Thematiq::Bundle

  def setup
    @store = OpenProject::Thematiq::Store.new(backend: MemoryBackend.new, env: {})
    @applied = []
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def run_with(env, ready: true)
    BootBundle.run(env:, store: @store, ready: -> { ready },
                   read: ->(text) { Bundle.read(text, catalogue: @store.catalogue) },
                   apply: lambda { |checked, digest|
                     @store.replace_setup(checked.settings)
                     @store.remember_bundle_file_digest(digest)
                     @applied << digest
                   })
  end

  def file(settings)
    path = File.join(@dir, "setup.json")
    File.write(path, Bundle.dump(Bundle.build(settings:, scopes: [])))
    path
  end

  def test_applied_once_and_again_only_when_the_file_changes
    path = file("active_id" => "zuiddrecht")

    assert_equal :applied, run_with({ BootBundle::FILE_KEY => path }).status
    assert_equal "zuiddrecht", @store.active_token_set.id
    @store.activate("amsterdam")
    assert_equal :unchanged, run_with({ BootBundle::FILE_KEY => path }).status
    assert_equal "amsterdam", @store.active_token_set.id, "a later change on the admin page stays"

    file("active_id" => "rotterdam")
    assert_equal :applied, run_with({ BootBundle::FILE_KEY => path }).status
    assert_equal 2, @applied.size
  end

  def test_off_not_ready_missing_and_refused
    assert_equal :off, run_with({}).status
    assert_equal :not_ready, run_with({ BootBundle::FILE_KEY => file("active_id" => "zuiddrecht") }, ready: false).status
    assert_equal :missing, run_with({ BootBundle::FILE_KEY => File.join(@dir, "none.json") }).status
    File.write(File.join(@dir, "bad.json"), '{"format":"openproject-thematiq-bundle","version":1,"settings":{"active_id":"nope"}}')
    outcome = run_with({ BootBundle::FILE_KEY => File.join(@dir, "bad.json") })
    assert_equal [:refused, "active"], [outcome.status, outcome.detail]
    assert_empty @applied
  end
end
