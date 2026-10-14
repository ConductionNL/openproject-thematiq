# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/assets"
require "tmpdir"

class AssetsTest < Minitest::Test
  Assets = OpenProject::Thematiq::Assets
  Catalogue = OpenProject::Thematiq::Catalogue
  TokenSet = OpenProject::Thematiq::Tokens::TokenSet

  SAFE_FACE = %r{\A@font-face \{ font-family: '[A-Za-z0-9 ]+'; font-style: (?:normal|italic); font-weight: (?:\d{3}|100 900); font-display: swap; src: url\((?:/[a-z0-9-]+)*/thematiq/fonts/[a-z0-9-]+\.woff2\) format\('woff2'\); \}\z}

  # The bundled sets whose first named font is not in the plugin: a system font, or a font the catalogue
  # does not mark redistributable. Their pages fall through the font stack. Measured on the vendored catalogue.
  NOT_BUNDLED = %w[borne cunningham denhaag drechterland duo enkhuizen haarlem haarlemmermeer horstaandemaas lasuite nextcloud
                   noaberkracht opencatalogi provincie-zuid-holland rotterdam stedebroec tilburg venray vng vught xxllnc zwolle].freeze

  def bundled = Assets.bundled
  def set(id) = Catalogue.bundled.find(id)

  # --- the files in the gem ---

  def test_every_font_file_in_the_gem_belongs_to_a_redistributable_family_of_the_catalogue
    fonts = JSON.parse(File.read(Catalogue::FILE))["fonts"]
    allowed = fonts.select { |font| font["redistributable"] == true }.flat_map { |font| font["files"].map { |path| File.basename(path) } }
    present = Dir.children(Assets::FONT_DIRECTORY).select { |name| name.end_with?(".woff2") }

    assert_operator present.size, :>, 40
    assert_empty present - allowed
  end

  def test_the_licence_texts_ship_with_the_fonts
    %w[OFL.txt OFL-inter.txt APACHE-2.0.txt].each { |name| assert File.file?(File.join(Assets::FONT_DIRECTORY, name)), name }
    assert_includes File.read(File.join(Assets::FONT_DIRECTORY, "OFL.txt")), "SIL Open Font License"
    assert_includes File.read(File.join(Assets::FONT_DIRECTORY, "OFL-inter.txt")), "Inter Project Authors"
  end

  def test_every_font_file_is_a_woff2_file
    Dir[File.join(Assets::FONT_DIRECTORY, "*.woff2")].each { |file| assert_equal "wOF2", File.binread(file, 4), file }
  end

  def test_nothing_but_logos_fonts_licence_texts_and_icons_is_served
    served = Dir[File.join(Assets::PUBLIC_DIRECTORY, "**", "*")].select { |path| File.file?(path) }

    served.each do |path|
      assert_match(%r{/public/thematiq/(?:logos/[a-z0-9-]+\.svg|fonts/[a-z0-9-]+\.woff2|fonts/[A-Za-z0-9.-]+\.txt|icons/[a-z-]+/[a-z0-9-]+\.svg)\z}, path)
    end
  end

  # --- fonts ---

  def test_a_bundled_family_gets_font_face_rules_with_swap
    css = bundled.font_face_css(set("amsterdam"))

    refute_empty css
    css.each_line(chomp: true) { |line| assert_match SAFE_FACE, line }
    assert_includes css, "font-family: 'Fira Sans'"
    assert_includes css, "url(/thematiq/fonts/fira-sans-latin-400-normal.woff2)"
    assert_equal "Fira Sans", bundled.named_family(set("amsterdam"))
    assert bundled.bundled_family?("Fira Sans")
  end

  def test_a_variable_font_gets_a_weight_range
    assert_includes bundled.font_face_css(set("conduction")), "font-weight: 100 900"
  end

  def test_the_mount_path_goes_in_front
    assert_includes bundled.font_face_css(set("amsterdam"), root: "/openproject"), "url(/openproject/thematiq/fonts/"
  end

  def test_a_family_that_is_not_bundled_gets_no_rule
    vng = set("vng")

    assert_equal "Avenir", bundled.named_family(vng)
    refute bundled.bundled_family?("Avenir")
    refute_includes bundled.font_face_css(vng), "Avenir"
  end

  def test_every_rule_for_every_bundled_set_is_safe_and_names_a_file_on_disk
    Catalogue.bundled.sets.each do |token_set|
      bundled.font_face_css(token_set).each_line(chomp: true) do |line|
        assert_match SAFE_FACE, line, token_set.id
        assert File.file?(File.join(Assets::FONT_DIRECTORY, line[%r{fonts/([a-z0-9-]+\.woff2)}, 1])), line
      end
    end
  end

  def test_how_many_bundled_sets_get_their_named_font_from_the_plugin
    loaded, not_loaded = Catalogue.bundled.sets.partition { |token_set| bundled.bundled_family?(bundled.named_family(token_set)) }

    assert_equal 67, loaded.size + not_loaded.size
    assert_equal (NOT_BUNDLED + OpenProject::Thematiq::Catalogue.own_ids).sort, not_loaded.map(&:id).sort
  end

  def test_a_hostile_fonts_list_gives_no_rule
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "evil-latin-400-normal.woff2"), "x")
      hostile = [
        { "family" => "Evil'; } body { display:none", "redistributable" => true, "files" => ["evil-latin-400-normal.woff2"] },
        { "family" => "Evil", "redistributable" => true, "files" => ["../../etc/passwd", "evil.woff2); } body { display:none", 7, nil] },
        { "family" => "Evil", "redistributable" => nil, "files" => ["evil-latin-400-normal.woff2"] },
        { "family" => "Evil", "redistributable" => "true", "files" => ["evil-latin-400-normal.woff2"] },
        { "family" => 7, "redistributable" => true, "files" => ["evil-latin-400-normal.woff2"] },
        "x", nil, { "family" => "Evil", "redistributable" => true, "files" => "evil-latin-400-normal.woff2" }
      ]
      assets = Assets.new(catalogue: Catalogue.bundled, fonts: hostile, font_directory: dir)
      token_set = TokenSet.from_set({ "id" => "t", "name" => "T", "tokens" => { "font-family" => "Evil, sans-serif" } })

      assert_equal "", assets.font_face_css(token_set)

      ok = Assets.new(catalogue: Catalogue.bundled, font_directory: dir,
                      fonts: [{ "family" => "Evil", "redistributable" => true, "files" => ["css/x/evil-latin-400-normal.woff2", "missing-latin-400-normal.woff2"] }])
      assert_equal 1, ok.font_face_css(token_set).lines.size
    end
  end

  # --- logos ---

  def test_the_top_bar_gets_the_variant_for_dark_backgrounds_when_there_is_one
    assert_equal "/thematiq/logos/zuiddrecht-dark.svg", bundled.logo_url(set("zuiddrecht"))
    assert_equal "/thematiq/logos/dinkelland.svg", bundled.logo_url(set("dinkelland"))
    assert_equal "/op/thematiq/logos/dinkelland.svg", bundled.logo_url(set("dinkelland"), root: "/op")
  end

  def test_a_set_whose_logo_is_not_redistributable_keeps_openprojects_logo
    assert_nil bundled.logo_url(set("amsterdam"))
    assert_nil bundled.logo_url(set("cunningham"))
    assert_equal 15, Catalogue.bundled.sets.count { |token_set| bundled.logo_url(token_set) }
  end

  def test_a_custom_set_keeps_the_logo_of_its_base
    draft = OpenProject::Thematiq::CustomDraft.new(base: set("zuiddrecht"), name: "Mine", overrides: { "primary" => "#aa0055" })

    assert_equal "/thematiq/logos/zuiddrecht-dark.svg", bundled.logo_url(draft.token_set)
  end

  def test_every_logo_address_is_plain
    Catalogue.bundled.sets.each do |token_set|
      url = bundled.logo_url(token_set)

      assert_match(%r{\A/thematiq/logos/[a-z0-9-]+\.svg\z}, url, token_set.id) if url
    end
  end
end
