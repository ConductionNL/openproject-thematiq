# frozen_string_literal: true

require "digest"
require "fileutils"
require "securerandom"
require "tmpdir"
require "open_project/thematiq/uploads"
require "open_project/thematiq/contrast"
require "open_project/thematiq/custom_draft"
require "open_project/thematiq/shell/core_guard"

module OpenProject
  module Thematiq
    # The logo, cover picture, footer picture, fonts and cover text colour of PDF exports, from the design system
    # of what is exported. OpenProject's exporters read these from the Enterprise design record, in four core files
    # with no extension point. PDFExport::Patches prepends small readers to those four, which answer from here and
    # otherwise call core's own reader. The plugin never reads or writes that record.
    #
    # Everything here is plain Ruby, so it is unit tested. The Rails side is in pdf_export/patches.rb, and it is only
    # loaded when the four core files are the ones it was written against (Shell::CoreGuard, part :pdf_export).
    module PDFExport
      IMAGE_KINDS = { logo: "export_logo", cover: "export_cover", footer: "export_footer" }.freeze
      # The cuts as OpenProject's exporter names them, and the upload kind of each.
      FONT_KINDS = { normal: "export_font_regular", bold: "export_font_bold", italic: "export_font_italic",
                     bold_italic: "export_font_bold_italic" }.freeze
      COVER_TEXT = "pdf-cover-text"
      DIRECTORY = File.join(Dir.tmpdir, "openproject-thematiq-pdf")

      # What one export is styled with, as upload records and a Prawn colour. nil means: OpenProject's own.
      # fonts holds a record for each of the four cuts, or is nil when there is no regular cut.
      Styling = Struct.new(:logo, :cover, :footer, :fonts, :cover_text_color, keyword_init: true) do
        def self.none = new
      end

      # The methods on an exporter that may lead to the project being exported, in order. A work package export
      # has its work package, a list its query, a meeting export its meeting. Without one: the instance.
      PROJECT_SOURCES = %i[project work_package query meeting object].freeze

      module_function

      # uploads: the Uploads::Record list of the design system. Only a custom design system has any.
      def styling(token_set, uploads)
        records = custom?(token_set) && uploads.is_a?(Array) ? uploads.select { |record| usable?(record, token_set) } : []
        pick = ->(kind) { records.reverse.find { |record| record.kind == kind } }

        Styling.new(**IMAGE_KINDS.transform_values { |kind| pick.call(kind) }, fonts: fonts(pick),
                    cover_text_color: prawn_color(token_set[COVER_TEXT]))
      end

      # OpenProject's order: a missing bold or italic cut is the regular one, a missing bold italic is the bold,
      # then the italic, then the regular one.
      def fonts(pick)
        regular = pick.call(FONT_KINDS[:normal])
        return nil unless regular

        bold = pick.call(FONT_KINDS[:bold])
        italic = pick.call(FONT_KINDS[:italic])
        { normal: regular, bold: bold || regular, italic: italic || regular,
          bold_italic: pick.call(FONT_KINDS[:bold_italic]) || bold || italic || regular }
      end

      # A colour as Prawn takes it: six hex digits without "#". nil for a see-through colour or one Contrast cannot read.
      def prawn_color(value)
        channels = Contrast.rgba(value)
        return nil unless channels && channels[3] == 1.0

        format("%02X%02X%02X", *channels.first(3).map(&:round))
      end

      def custom?(token_set)
        token_set.respond_to?(:id) && token_set.id.is_a?(String) && CustomDraft::ID_PATTERN.match?(token_set.id)
      end

      def usable?(record, token_set)
        record.is_a?(Uploads::Record) && record.set_id == token_set.id && record.usable? && Uploads.kind(record.kind)&.pdf?
      end

      # The project of an exporter, or nil. project: says whether a value is a project.
      def project_of(exporter, project:)
        PROJECT_SOURCES.each do |name|
          next unless exporter.respond_to?(name, true) && no_arguments?(exporter.method(name))

          value = exporter.send(name)
          return value if project.call(value)

          owner = value.respond_to?(:project) ? value.project : nil
          return owner if project.call(owner)
        rescue StandardError
          next
        end
        nil
      end

      def no_arguments?(method)
        method.parameters.none? { |type, _name| %i[req keyreq].include?(type) }
      end

      # The path of a file for Prawn, which reads files by path and decides a font's type by its extension.
      # The file is written once under its checksum, and checked against that checksum each time. nil when it cannot
      # be had: the exporter then keeps OpenProject's file. bytes: answers call(token) with the stored bytes.
      def file_path(record, bytes:, directory: DIRECTORY)
        return nil unless record.is_a?(Uploads::Record) && private_directory(directory)

        path = File.join(directory, "#{record.sha256}.#{record.format == 'jpeg' ? 'jpg' : record.format}")
        return path if File.file?(path) && !File.symlink?(path) && Digest::SHA256.file(path).hexdigest == record.sha256

        data = bytes.call(record.token)
        return nil unless data.is_a?(String) && data.bytesize == record.byte_size && Digest::SHA256.hexdigest(data) == record.sha256

        temporary = "#{path}.#{SecureRandom.hex(8)}.tmp"
        File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, 0o600, binmode: true) { |file| file.write(data.b) }
        File.rename(temporary, path)
        path
      rescue SystemCallError, IOError, EncodingError
        File.delete(temporary) if temporary && File.exist?(temporary)
        nil
      end

      # The folder, made for this process's user alone. nil when it is someone else's or others may write to it.
      def private_directory(directory)
        FileUtils.mkdir_p(directory, mode: 0o700)
        stat = File.lstat(directory)
        stat.directory? && stat.owned? && (stat.mode & 0o022).zero? ? directory : nil
      rescue SystemCallError
        nil
      end

      # Called from the engine's to_prepare block. The patches are only installed when the four core files are the
      # ones they were written against. On any other OpenProject version exports keep core's styling, and the log
      # names the files that moved.
      def install!(logger:, changed: Shell::CoreGuard.changed_files(part: :pdf_export))
        unless changed.empty?
          logger.error(
            "[openproject-thematiq] The PDF export patches are off. These core files differ from OpenProject " \
            "#{Shell::CoreGuard::CORE_VERSION}: #{changed.join(', ')}. See docs/enterprise-parity.md, \"PDF export styling\"."
          )
          return false
        end

        require "open_project/thematiq/pdf_export/patches"
        Patches.install!
        true
      end
    end
  end
end
