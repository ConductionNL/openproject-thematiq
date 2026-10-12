# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class CatalogueTest < Minitest::Test
  Catalogue = OpenProject::Thematiq::Catalogue
  Defaults = OpenProject::Thematiq::Tokens::Defaults

  def set(id, name = id.capitalize, tokens = {}, logo = nil)
    { "id" => id, "name" => name, "tokens" => { "primary" => "#3669a5" }.merge(tokens), "logo" => logo }
  end

  def document(*sets, **extra)
    { "version" => 1, "generated_from" => "test", "sets" => sets, "fonts" => [] }.merge(extra.transform_keys(&:to_s))
  end

  # --- the file that ships with the plugin ---

  def test_the_bundled_catalogue_loads_without_an_error
    catalogue = Catalogue.bundled

    assert_nil catalogue.error
    assert_equal 0, catalogue.skipped
    refute_empty catalogue.sets
  end

  def test_the_bundled_catalogue_has_cunningham_as_the_default
    assert_equal "cunningham", Catalogue.bundled.default.id
    assert_equal "cunningham", Catalogue.bundled.sets.first.id
  end

  def test_no_value_in_the_bundled_catalogue_is_refused
    raw = JSON.parse(File.read(Catalogue::FILE))

    assert_equal raw["sets"].size, Catalogue.bundled.sets.size
    Catalogue.bundled.sets.each { |token_set| assert_empty token_set.rejected, token_set.id }
  end

  def test_every_bundled_set_generates_safe_css
    Catalogue.bundled.sets.each do |token_set|
      css = OpenProject::Thematiq::Variables::Generator.new(token_set).css

      refute_match(/[<>\\@]|url\(|!important/, css, token_set.id)
      assert_equal 3, css.count("{"), token_set.id
    end
  end

  def test_every_logo_the_bundled_catalogue_names_is_in_the_gem_and_nothing_else_is
    named = Catalogue.bundled.sets.flat_map { |s| [s.logo_file, s.logo_inverse_file] }.compact.uniq.sort
    present = Dir.children(Catalogue::LOGO_DIRECTORY).reject { |name| name.start_with?(".") }.sort

    assert_equal named, present
  end

  def test_cunningham_matches_the_last_resort_values
    assert_equal Defaults::TOKENS, Catalogue.bundled.find("cunningham").tokens.slice(*Defaults::TOKENS.keys)
  end

  # --- loading ---

  def test_orders_the_default_first_and_then_by_name
    catalogue = Catalogue.from_document(document(set("zuiddrecht"), set("amsterdam"), set("cunningham"), set("Breda", "breda")))

    assert_equal %w[cunningham amsterdam Breda zuiddrecht], catalogue.sets.map(&:id)
  end

  def test_without_cunningham_the_first_set_is_the_default
    assert_equal "amsterdam", Catalogue.from_document(document(set("zuiddrecht"), set("amsterdam"))).default.id
  end

  def test_skips_entries_that_are_not_sets_and_duplicate_ids
    catalogue = Catalogue.from_document(document(set("a"), "x", nil, { "id" => "../etc" }, { "id" => "b" }, set("a", "Second a"), set("c")))

    assert_equal %w[a c], catalogue.sets.map(&:id)
    assert_equal "A", catalogue.find("a").name
    assert_equal 5, catalogue.skipped
    assert_nil catalogue.error
  end

  def test_a_hostile_value_in_the_file_falls_back_and_is_listed
    catalogue = Catalogue.from_document(document(set("a", "A", "primary" => "red; } body { display:none", "radius" => "1px} *{")))
    token_set = catalogue.find("a")

    assert_equal Defaults::TOKENS["primary"], token_set["primary"]
    assert_equal Defaults::TOKENS["radius"], token_set["radius"]
    assert_equal %w[primary radius], token_set.rejected
  end

  def test_every_hostile_value_in_every_token_of_a_catalogue_set
    OpenProject::Thematiq::Tokens::TokenSet::KINDS.each_key do |key|
      HOSTILE_VALUES.each do |value|
        token_set = Catalogue.from_document(document(set("a", "A", key => value))).find("a")
        css = OpenProject::Thematiq::Variables::Generator.new(token_set).css

        refute_match(/[<>\\@]|url\(|expression|display|!important/i, css, "#{key} = #{value.inspect}")
      end
    end
  end

  def test_a_hostile_name_is_cleaned_or_replaced_by_the_id
    catalogue = Catalogue.from_document(document(set("a", "x" * 500), set("b", "line\nbreak"), set("c", 7)))

    assert_equal "a", catalogue.find("a").name
    assert_equal "line break", catalogue.find("b").name
    assert_equal "c", catalogue.find("c").name
  end

  def test_documents_that_cannot_be_used_give_the_last_resort_set_and_an_error
    { nil => "not_an_object", [] => "not_an_object", document(version: 2) => "unsupported_version",
      { "version" => 1 } => "sets_missing", document(sets: "x") => "sets_missing", document => "no_usable_sets",
      document("x", 1) => "no_usable_sets",
      document(*Array.new(Catalogue::MAX_SETS + 1) { |i| set("s#{i}") }) => "too_many_sets" }.each do |doc, error|
      catalogue = Catalogue.from_document(doc)

      assert_equal error, catalogue.error
      assert_equal ["cunningham"], catalogue.sets.map(&:id)
      assert_equal Defaults::TOKENS, catalogue.default.tokens
    end
  end

  def test_files_that_cannot_be_used
    Dir.mktmpdir do |dir|
      assert_equal "missing", Catalogue.load(File.join(dir, "nope.json")).error

      File.write(File.join(dir, "bad.json"), "{ not json")
      assert_equal "invalid_json", Catalogue.load(File.join(dir, "bad.json")).error

      File.write(File.join(dir, "big.json"), " " * (Catalogue::MAX_BYTES + 1))
      assert_equal "too_large", Catalogue.load(File.join(dir, "big.json")).error

      File.write(File.join(dir, "ok.json"), JSON.generate(document(set("a"))))
      assert_equal %w[a], Catalogue.load(File.join(dir, "ok.json")).sets.map(&:id)
    end
  end

  # --- search ---

  def test_search
    catalogue = Catalogue.from_document(document(set("cunningham"), set("gemeente-zuiddrecht", "Gemeente Zuiddrecht"),
                                                 set("gemeente-breda", "Gemeente Breda"), set("rijkshuisstijl", "Rijkshuisstijl")))

    assert_equal 4, catalogue.search("").size
    assert_equal 4, catalogue.search(nil).size
    assert_equal 4, catalogue.search("   ").size
    assert_equal %w[gemeente-breda gemeente-zuiddrecht], catalogue.search("GEMEENTE").map(&:id)
    assert_equal %w[gemeente-zuiddrecht], catalogue.search("zuid gemeente").map(&:id)
    assert_equal %w[rijkshuisstijl], catalogue.search("rijks").map(&:id)
    assert_empty catalogue.search("nothing like this")
    assert_empty catalogue.search("<script>")
  end

  # --- logos ---

  def test_logo_path_needs_a_named_file_that_exists_in_the_logo_directory
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "a.svg"), "<svg/>")
      logo = { "file" => "a.svg", "inverse_file" => "a-inverse.svg", "licence" => "CC0-1.0", "redistributable" => true }
      catalogue = Catalogue.from_document(document(set("a", "A", {}, logo), set("b", "B", {}, logo.merge("redistributable" => false)), set("c")),
                                          logo_directory: dir)

      assert_equal File.join(dir, "a.svg"), catalogue.logo_path(catalogue.find("a"))
      assert_nil catalogue.logo_path(catalogue.find("a"), inverse: true), "the inverse file is not on disk"
      assert_nil catalogue.logo_path(catalogue.find("b")), "not redistributable"
      assert_nil catalogue.logo_path(catalogue.find("c")), "no logo"
    end
  end
end
