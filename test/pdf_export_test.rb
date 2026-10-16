# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "open_project/thematiq"
require "open_project/thematiq/pdf_export"

# Which logo, pictures, fonts and cover colour a PDF export gets, and how the files reach Prawn.
class PDFExportTest < Minitest::Test
  Thematiq = OpenProject::Thematiq
  PDFExport = Thematiq::PDFExport
  Uploads = Thematiq::Uploads
  Catalogue = Thematiq::Catalogue
  Guard = Thematiq::Shell::CoreGuard

  def record(kind, format, character, set_id: "custom", bytes: nil)
    bytes ||= "#{kind}-#{character}".b
    Uploads::Record.build(token: character * 64, set_id:, kind:, format:, byte_size: bytes.bytesize,
                          sha256: Digest::SHA256.hexdigest(bytes))
  end

  def custom(overrides = {}, id: "custom")
    Thematiq::CustomDraft.new(base: Catalogue.bundled.find("zuiddrecht"), name: "Mine", overrides:, id:).token_set
  end

  # --- what an export gets ---

  def test_a_design_system_without_pdf_files_leaves_everything_to_core
    styling = PDFExport.styling(custom, [record("logo", "svg", "a"), record("font", "woff2", "b")])

    assert_equal PDFExport::Styling.none, styling
  end

  def test_each_picture_comes_from_its_own_kind
    logo = record("export_logo", "png", "a")
    cover = record("export_cover", "jpeg", "b")
    footer = record("export_footer", "png", "c")
    styling = PDFExport.styling(custom, [footer, record("logo", "png", "d"), cover, logo])

    assert_equal [logo, cover, footer], [styling.logo, styling.cover, styling.footer]
  end

  def test_the_newest_file_of_a_kind_wins
    styling = PDFExport.styling(custom, [record("export_logo", "png", "a"), record("export_logo", "png", "b")])

    assert_equal "b" * 64, styling.logo.token
  end

  def test_a_catalogue_design_system_has_no_pdf_files
    zuiddrecht = Catalogue.bundled.find("zuiddrecht")
    styling = PDFExport.styling(zuiddrecht, [record("export_logo", "png", "a", set_id: zuiddrecht.id)])

    assert_nil styling.logo
  end

  def test_files_of_another_design_system_are_not_used
    styling = PDFExport.styling(custom(id: "custom-2"), [record("export_logo", "png", "a"), "x", nil])

    assert_nil styling.logo
  end

  def test_the_font_cuts_fall_back_as_core_does
    regular = record("export_font_regular", "ttf", "a")
    bold = record("export_font_bold", "ttf", "b")
    italic = record("export_font_italic", "ttf", "c")
    bold_italic = record("export_font_bold_italic", "ttf", "d")

    assert_equal({ normal: regular, bold: regular, italic: regular, bold_italic: regular }, PDFExport.styling(custom, [regular]).fonts)
    assert_equal({ normal: regular, bold:, italic: regular, bold_italic: bold }, PDFExport.styling(custom, [regular, bold]).fonts)
    assert_equal({ normal: regular, bold: regular, italic:, bold_italic: italic }, PDFExport.styling(custom, [italic, regular]).fonts)
    assert_equal({ normal: regular, bold:, italic:, bold_italic: }, PDFExport.styling(custom, [regular, bold, italic, bold_italic]).fonts)
  end

  def test_without_a_regular_cut_the_fonts_stay_cores
    styling = PDFExport.styling(custom, [record("export_font_bold", "ttf", "b"), record("export_font_italic", "ttf", "c")])

    assert_nil styling.fonts
  end

  def test_the_cover_colour_is_a_prawn_colour
    assert_equal "1A2B3C", PDFExport.styling(custom({ "pdf-cover-text" => "#1a2b3c" }), []).cover_text_color
    assert_equal "FFCC00", PDFExport.styling(custom({ "pdf-cover-text" => "#fc0" }), []).cover_text_color
    assert_equal "0A141E", PDFExport.styling(custom({ "pdf-cover-text" => "rgb(10, 20, 30)" }), []).cover_text_color
  end

  def test_a_cover_colour_prawn_cannot_take_is_left_to_core
    assert_nil PDFExport.styling(custom, []).cover_text_color
    assert_nil PDFExport.styling(custom({ "pdf-cover-text" => "rgba(10, 20, 30, 0.5)" }), []).cover_text_color
    assert_nil PDFExport.styling(custom({ "pdf-cover-text" => "teal" }), []).cover_text_color
    assert_nil PDFExport.prawn_color("#1a2b3c; } x")
    assert_nil PDFExport.prawn_color(nil)
  end

  def test_the_cover_colour_is_a_role_that_travels_but_has_no_dark_value
    token_set = Thematiq::Tokens::TokenSet.from_set({ "id" => "x", "name" => "X", "tokens" => { "pdf-cover-text" => "#112233" } }, strict: true)

    assert_equal "#112233", token_set["pdf-cover-text"]
    refute_includes Thematiq::Tokens::TokenSet::DARK_KEYS, "pdf-cover-text"
    assert_raises(Thematiq::Tokens::TokenSet::InvalidSet) do
      Thematiq::Tokens::TokenSet.from_set({ "id" => "x", "name" => "X", "tokens" => { "pdf-cover-text" => "red; } x" } }, strict: true)
    end
  end

  # --- the project of an export ---

  Project = Struct.new(:id)
  WorkPackage = Struct.new(:project)
  Query = Struct.new(:project)
  WorkPackageExporter = Struct.new(:work_package)
  ListExporter = Struct.new(:query)
  OwnProjectExporter = Struct.new(:project)

  class Exporter
    def object = raise("no object")
  end

  def project?(value) = value.is_a?(Project)

  def project_of(exporter) = PDFExport.project_of(exporter, project: method(:project?))

  def test_the_project_comes_from_what_is_exported
    demo = Project.new(1)

    assert_equal demo, project_of(WorkPackageExporter.new(WorkPackage.new(demo)))
    assert_equal demo, project_of(ListExporter.new(Query.new(demo)))
    assert_equal demo, project_of(OwnProjectExporter.new(demo))
  end

  def test_without_a_project_the_export_has_the_instances_design_system
    assert_nil project_of(ListExporter.new(Query.new(nil)))
    assert_nil project_of(Exporter.new)
    assert_nil project_of(Object.new)
  end

  # --- files for Prawn ---

  def with_directory
    Dir.mktmpdir do |root|
      yield File.join(root, "pdf")
    end
  end

  def test_a_file_is_written_once_under_its_checksum
    bytes = "\x89PNG picture".b
    logo = record("export_logo", "png", "a", bytes:)
    asked = 0
    source = lambda do |token|
      asked += 1
      token == logo.token ? bytes : nil
    end

    with_directory do |directory|
      path = PDFExport.file_path(logo, bytes: source, directory:)

      assert_equal File.join(directory, "#{logo.sha256}.png"), path
      assert_equal bytes, File.binread(path)
      assert_equal path, PDFExport.file_path(logo, bytes: source, directory:)
      assert_equal 1, asked
      assert_equal 0o700, File.stat(directory).mode & 0o777
      assert_equal 0o600, File.stat(path).mode & 0o777
    end
  end

  def test_a_font_keeps_the_extension_prawn_reads_its_type_from
    font = record("export_font_regular", "ttf", "a", bytes: "font".b)
    jpeg = record("export_cover", "jpeg", "b", bytes: "jpeg".b)

    with_directory do |directory|
      assert PDFExport.file_path(font, bytes: ->(_) { "font".b }, directory:).end_with?(".ttf")
      assert PDFExport.file_path(jpeg, bytes: ->(_) { "jpeg".b }, directory:).end_with?(".jpg")
    end
  end

  def test_bytes_that_do_not_match_the_record_give_no_file
    logo = record("export_logo", "png", "a", bytes: "right".b)

    with_directory do |directory|
      assert_nil PDFExport.file_path(logo, bytes: ->(_) { "wrong".b }, directory:)
      assert_nil PDFExport.file_path(logo, bytes: ->(_) { nil }, directory:)
      assert_nil PDFExport.file_path(logo, bytes: ->(_) { "right!".b }, directory:)
      assert_empty Dir.children(directory)
    end
  end

  def test_a_file_changed_on_disk_is_written_again
    logo = record("export_logo", "png", "a", bytes: "right".b)

    with_directory do |directory|
      path = PDFExport.file_path(logo, bytes: ->(_) { "right".b }, directory:)
      File.binwrite(path, "other")

      assert_equal path, PDFExport.file_path(logo, bytes: ->(_) { "right".b }, directory:)
      assert_equal "right", File.binread(path)
    end
  end

  def test_a_folder_others_may_write_to_is_not_used
    logo = record("export_logo", "png", "a", bytes: "right".b)

    with_directory do |directory|
      Dir.mkdir(directory)
      File.chmod(0o777, directory)

      assert_nil PDFExport.file_path(logo, bytes: ->(_) { "right".b }, directory:)
    end
  end

  def test_something_that_is_not_a_record_gives_no_file
    with_directory do |directory|
      assert_nil PDFExport.file_path(nil, bytes: ->(_) { "x" }, directory:)
      assert_nil PDFExport.file_path("../../etc/passwd", bytes: ->(_) { "x" }, directory:)
    end
  end

  # --- the core files ---

  def test_the_four_exporter_files_are_one_part_of_the_guard
    part = Guard::PARTS.fetch(:pdf_export)

    assert_equal %w[app/models/exports/pdf/common/logo.rb app/models/exports/pdf/components/cover.rb
                    app/models/exports/pdf/components/page.rb app/models/exports/pdf/common/view.rb], part
    part.each { |path| assert Guard::FILES.key?(path), "#{path} has no checksum" }
  end

  def test_a_changed_exporter_file_switches_only_this_part_off
    Dir.mktmpdir do |root|
      Guard::PARTS.fetch(:pdf_export).each do |path|
        FileUtils.mkdir_p(File.join(root, File.dirname(path)))
        File.write(File.join(root, path), "changed")
      end

      assert_equal Guard::PARTS.fetch(:pdf_export), Guard.changed_files(root, part: :pdf_export)
      assert_equal Guard::PARTS.fetch(:gantt), Guard.changed_files(root, part: :gantt), "the other parts only see their own files"
    end
  end

  def test_the_patches_are_not_installed_when_a_file_changed
    logger = Struct.new(:lines) { def error(line) = lines << line }.new([])
    refute PDFExport.install!(logger:, changed: ["app/models/exports/pdf/common/view.rb"])

    assert_match(/PDF export patches are off.*view\.rb/, logger.lines.first)
  end
end
