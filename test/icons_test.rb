# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/icons"
require "open_project/thematiq/uploads"

class IconsTest < Minitest::Test
  Icons = OpenProject::Thematiq::Icons
  ROOT = File.expand_path("..", __dir__)

  def test_the_inventory_matches_the_files_and_names_every_licence
    assert_equal %w[den-haag dsfr open-gemeenten rvo], Icons.sets.keys.sort
    Icons.sets.each do |set, entry|
      refute_empty entry["licence"], set
      files = Dir[File.join(ROOT, "public/thematiq/icons", set, "*.svg")].map { |path| File.basename(path, ".svg") }.sort
      assert_equal entry["names"].sort, files, set
      assert_equal entry["count"], files.size, set
    end
  end

  def test_every_icon_is_an_svg_document_the_sanitiser_keeps_as_it_is
    Dir[File.join(ROOT, "public/thematiq/icons/**/*.svg")].each do |path|
      text = File.read(path)
      assert_match(/\A<\?xml version="1\.0" encoding="UTF-8"\?>\n<svg\b[^>]*>.*<\/svg>\n\z/m, text, path)
      assert_equal text, OpenProject::Thematiq::Uploads::Svg.sanitise(text).text, path
    end
  end

  def test_no_icon_holds_script_or_a_reference_outward
    Dir[File.join(ROOT, "public/thematiq/icons/**/*.svg")].each do |path|
      text = File.read(path)
      refute_match(/<script|javascript:|on[a-z]+\s*=|xlink:href\s*=\s*["'](?!#)|href\s*=\s*["'](?!#)|<foreignObject/i, text, path)
    end
  end

  def test_an_icon_by_name
    name = Icons.sets["rvo"]["names"].first
    assert_equal "/thematiq/icons/rvo/#{name}.svg", Icons.url("rvo", name)
    assert_nil Icons.url("rvo", "../../etc/passwd")
    assert_nil Icons.url("amsterdam", name)
  end
end
