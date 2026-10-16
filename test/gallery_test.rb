# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/gallery"
require "open_project/thematiq/gallery/client"

class GalleryTest < Minitest::Test
  Gallery = OpenProject::Thematiq::Gallery
  Catalogue = OpenProject::Thematiq::Catalogue

  def store(data = {})
    OpenProject::Thematiq::Store.new(backend: MemoryBackend.new(data), env: {})
  end

  def test_off_by_default_and_then_the_client_opens_nothing
    refute store.gallery_enabled?
    assert_raises(Gallery::Off) { Gallery::Client.fetch(Gallery::DEFAULT_URL, enabled: false) }
    refute defined?(Net::HTTP), "no http library was loaded by a refused fetch"
  end

  def test_only_https_addresses
    assert Gallery.valid_url?(Gallery::DEFAULT_URL)
    ["http://example.org/c.json", "https://user:pw@example.org/c.json", "javascript:alert(1)", "file:///etc/passwd", "https://", "x" * 600].each do |url|
      refute Gallery.valid_url?(url), url
      assert_raises(Gallery::Refused) { Gallery::Client.fetch(url, enabled: true) }
    end
    s = store
    refute s.save_gallery_settings(enabled: true, url: "http://example.org/c.json")
    assert s.save_gallery_settings(enabled: true, url: "")
    assert_equal Gallery::DEFAULT_URL, s.gallery_url
  end

  def test_the_answer_is_read_by_the_catalogues_own_loader
    local = Catalogue.bundled
    document = JSON.parse(File.read(Catalogue::FILE))
    document["generated_from"] = "thematiq development newer"
    document["sets"] << { "id" => "gallery-new", "name" => "Gallery new", "tokens" => { "primary" => "#123456" } }
    document["sets"].find { |set| set["id"] == "zuiddrecht" }["tokens"]["primary"] = "#aa0055"
    gallery = Gallery.read(JSON.generate(document))

    assert_equal %w[gallery-new zuiddrecht], Gallery.new_or_changed(gallery, local).map(&:id).sort
    assert_raises(Gallery::Refused) { Gallery.read("<html>") }
    assert_raises(Gallery::Refused) { Gallery.read('{"version":1,"sets":[]}') }
  end

  def test_the_notice_until_dismissed
    s = store("gallery_enabled" => true)
    s.record_gallery_status("checked_at" => 1, "generated_from" => "thematiq development newer", "sets" => 70, "new" => 3)
    assert_equal 3, s.gallery_notice["new"]
    s.dismiss_gallery_notice
    assert_nil s.gallery_notice
    s.record_gallery_status("checked_at" => 2, "generated_from" => Catalogue.bundled.generated_from, "sets" => 64, "new" => 0)
    assert_nil s.gallery_notice, "no notice for the catalogue the plugin has"
  end

  def test_due_once_a_day
    assert Gallery.due?(nil)
    refute Gallery.due?(Time.now.to_i - 60)
    assert Gallery.due?(Time.now.to_i - Gallery::CHECK_EVERY)
  end

  def test_the_appearance_link_is_off_by_default
    s = store
    refute s.appearance_link_enabled?
    s.save_appearance_link(true)
    assert s.appearance_link_enabled?
  end
end
