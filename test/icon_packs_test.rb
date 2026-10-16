# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/icon_packs"

class IconPacksTest < Minitest::Test
  IconPacks = OpenProject::Thematiq::IconPacks
  ROOT = File.expand_path("..", __dir__)

  def test_the_design_systems_name_thematiqs_packs
    assert_equal %w[rvo open-gemeenten den-haag], IconPacks.design_systems["nldesign"]
    assert_equal %w[dsfr], IconPacks.design_systems["lasuite"]
    assert_empty IconPacks.design_systems["high-contrast"]
  end

  def test_a_dutch_set_follows_den_haag_and_a_french_one_dsfr
    dutch = IconPacks.resolve("utrecht")
    assert_equal %w[rvo open-gemeenten den-haag], dutch.packs
    assert_equal :design_system, dutch.source
    assert_equal "nldesign", dutch.design_system
    assert_equal "den-haag", dutch.drawn_by, "rvo and open-gemeenten are pictograms and map nothing"

    french = IconPacks.resolve("lasuite")
    assert_equal %w[dsfr], french.packs
    assert_equal "dsfr", french.drawn_by
  end

  def test_a_set_of_a_design_system_without_a_pack_and_an_unknown_set_keep_core_icons
    %w[hoog-contrast nextcloud cunningham conduction openproject-default no-such-set].each do |id|
      resolution = IconPacks.resolve(id)
      assert_empty resolution.packs, id
      assert_nil resolution.drawn_by, id
      refute resolution.active?, id
    end
  end

  def test_a_custom_design_system_follows_its_base
    assert_equal "dsfr", IconPacks.resolve("custom-1", base_id: "lasuite").drawn_by
    assert_equal "den-haag", IconPacks.resolve("custom-1", base_id: "rijkshuisstijl").drawn_by
  end

  def test_the_administrator_wins_and_none_means_none
    assert_equal "dsfr", IconPacks.resolve("utrecht", choice: "dsfr").drawn_by
    assert_equal :override, IconPacks.resolve("utrecht", choice: "dsfr").source
    none = IconPacks.resolve("lasuite", choice: "none")
    assert_nil none.drawn_by
    assert_equal :override, none.source
    assert_equal %w[den-haag dsfr], IconPacks.choosable
    refute IconPacks.valid_choice?("rvo"), "a pack that maps nothing cannot draw OpenProject's icons"
    refute IconPacks.valid_choice?("../dsfr")
    assert IconPacks.valid_choice?("")
  end

  def test_every_catalogue_set_has_a_design_system_or_none_on_purpose
    sets = JSON.parse(File.read(File.join(ROOT, "data/catalogue/shell-catalogue.json")))["sets"].map { |set| set["id"] }
    assert_equal %w[conduction], sets - IconPacks.token_sets.keys, "only the plugin's own set is not one of thematiq's"
  end

  def test_every_mapped_icon_fits_an_octicon
    IconPacks.maps.each do |pack, map|
      built = IconPacks.build(pack)
      assert_equal map.keys.sort, built["icons"].keys, pack
      built["icons"].each do |name, icon|
        assert_kind_of Integer, icon["height"], "#{pack} #{name}"
        assert icon["width"].positive?, "#{pack} #{name}"
        refute_empty icon["paths"], "#{pack} #{name}"
        assert_includes %w[nonzero evenodd], icon["fill_rule"], "#{pack} #{name}"
      end
    end
  end

  def test_an_icon_with_a_stroke_or_a_shape_is_refused
    error = assert_raises(IconPacks::Unusable) { IconPacks.shape(File.join(ROOT, "public/thematiq/icons/den-haag/dh-functional-checked.svg"), "x") }
    assert_match(/stroke/, error.message)
    error = assert_raises(IconPacks::Unusable) { IconPacks.shape(File.join(ROOT, "public/thematiq/icons/den-haag/dh-informational-alert-triangle-filled.svg"), "x") }
    assert_match(/<circle>|<rect>|<g>/, error.message)
  end

  def test_the_payload_is_json_the_module_reads
    payload = JSON.parse(IconPacks.payload("dsfr"))
    assert_equal "dsfr", payload["pack"]
    assert_equal IconPacks.maps["dsfr"].size, payload["icons"].size
    assert_nil IconPacks.payload("rvo")
  end

  def test_the_frontend_targets_are_in_step_with_the_maps
    assert_equal IconPacks.targets_source, File.read(File.join(ROOT, "frontend/module/icon-pack/targets.ts")),
                 "run script/build-icon-packs.rb"
    assert_equal "opPhoneIconData", IconPacks.data_constant("op-phone")
    assert_equal "xIconData", IconPacks.data_constant("x")
  end
end

require "open_project/thematiq/bundle"

class IconPackChoiceTest < Minitest::Test
  Store = OpenProject::Thematiq::Store
  Bundle = OpenProject::Thematiq::Bundle

  def test_the_store_keeps_a_valid_choice_and_refuses_the_rest
    store = Store.new(backend: MemoryBackend.new)
    assert_equal "", store.icon_pack_choice
    assert store.save_icon_pack_choice("dsfr")
    assert_equal "dsfr", store.icon_pack_choice
    assert store.save_icon_pack_choice("none")
    assert_equal "none", store.icon_pack_choice
    ["rvo", "../dsfr", "DSFR", "x"].each { |value| refute store.save_icon_pack_choice(value), value }
    assert_equal "none", store.icon_pack_choice
    assert store.save_icon_pack_choice("")
    assert_equal "", store.icon_pack_choice
  end

  def test_a_stored_value_that_is_no_longer_a_pack_follows_the_design_system
    assert_equal "", Store.new(backend: MemoryBackend.new("icon_pack" => "gone")).icon_pack_choice
  end

  def test_a_configuration_file_carries_the_choice_and_refuses_an_unknown_one
    catalogue = OpenProject::Thematiq::Catalogue.bundled
    bundle = Bundle.build(settings: { "active_id" => "cunningham", "icon_pack" => "dsfr" }, scopes: [], plugin_version: "0.2.0")
    assert_equal "dsfr", Bundle.read(Bundle.dump(bundle), catalogue:).settings["icon_pack"]

    bundle["settings"]["icon_pack"] = "rvo"
    error = assert_raises(Bundle::Refused) { Bundle.read(Bundle.dump(bundle), catalogue:) }
    assert_equal "icon_pack", error.code
  end
end
