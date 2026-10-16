# frozen_string_literal: true

module OpenProject
  module Thematiq
    module PDFExport
      # The readers prepended to OpenProject's four PDF exporter files. Each one asks PDFExport for the value of the
      # design system of what is exported, and calls core's own reader (super) when the plugin has none.
      #
      # Written against these files of OpenProject 17.9.1, which Shell::CoreGuard checks (part :pdf_export):
      #   app/models/exports/pdf/common/logo.rb       custom_logo_image_filename
      #   app/models/exports/pdf/components/cover.rb  validate_cover_text_color, custom_cover_image_file
      #   app/models/exports/pdf/components/page.rb   custom_footer_image, configure_page_size!
      #   app/models/exports/pdf/common/view.rb       View.valid_custom_font?, View#custom_font_files
      #
      # The fonts are read by the View, which knows nothing of the exporter, and partly by class methods. So the
      # exporter's styling is kept in Current from configure_page_size!, which every exporter with pages calls before
      # its document exists. Rails resets Current after each request and each job. Without it the View answers
      # from the instance's design system, the same answer every time it asks, so the font it names is registered.
      module Patches
        class Current < ActiveSupport::CurrentAttributes
          attribute :styling
        end

        module_function

        def install!
          ::Exports::PDF::Common::Logo.prepend(Logo)
          ::Exports::PDF::Components::Cover.prepend(Cover)
          ::Exports::PDF::Components::Page.prepend(Page)
          ::Exports::PDF::Common::View.prepend(View)
          ::Exports::PDF::Common::View.singleton_class.prepend(View::ClassMethods)
        end

        # Never raises: a design plugin must not be the reason an export fails. Then core's styling stays.
        def styling_for(project)
          token_set = PageScope.compute(project:, controller: nil).page_set
          PDFExport.styling(token_set, PDFExport.custom?(token_set) ? ::Thematiq::Upload.records_for(token_set.id) : [])
        rescue StandardError => e
          Rails.logger.error("[openproject-thematiq] A PDF export keeps OpenProject's styling: #{e.class}: #{e.message}")
          Styling.none
        end

        def project_of(exporter)
          PDFExport.project_of(exporter, project: ->(value) { value.is_a?(::Project) && value.persisted? })
        end

        def file_path(record)
          PDFExport.file_path(record, bytes: ->(token) { ::Thematiq::Upload.bytes_for(token) })
        end

        # The styling the View reads: the exporter's, else the instance's.
        def current_styling
          Current.styling ||= styling_for(nil)
        end

        # The four font files, or nil. A cut whose file cannot be had or read takes the regular one.
        def font_paths(styling)
          fonts = styling&.fonts
          regular = fonts && readable_font(fonts[:normal])
          return nil unless regular

          fonts.to_h { |cut, record| [cut, readable_font(record) || regular] }
        end

        def readable_font(record)
          path = file_path(record)
          path if path && TTFunk::File.open(path).name
        rescue StandardError => e
          Rails.logger.error("[openproject-thematiq] A PDF font of the design system cannot be read: #{e.class}: #{e.message}")
          nil
        end

        # What the three exporter modules share: the styling of this export, once, and a picture Prawn can embed.
        module Exporter
          private

          def thematiq_pdf_styling
            return @thematiq_pdf_styling if defined?(@thematiq_pdf_styling)

            @thematiq_pdf_styling = Patches.styling_for(Patches.project_of(self))
          end

          # The path of the design system's picture of this kind, or nil. Prawn reads it once here, so a file it
          # cannot embed falls back to core's picture instead of stopping the export.
          def thematiq_pdf_image(kind)
            record = thematiq_pdf_styling.public_send(kind)
            path = record && Patches.file_path(record)
            return nil unless path

            pdf.build_image_object(path)
            path
          rescue StandardError => e
            Rails.logger.error("[openproject-thematiq] The PDF #{kind} of the design system cannot be used: #{e.class}: #{e.message}")
            nil
          end
        end

        module Logo
          include Exporter

          def custom_logo_image_filename
            thematiq_pdf_image(:logo) || super
          end
        end

        module Cover
          include Exporter

          def validate_cover_text_color
            thematiq_pdf_styling.cover_text_color || super
          end

          def custom_cover_image_file
            thematiq_pdf_image(:cover) || super
          end
        end

        module Page
          include Exporter

          def configure_page_size!(layout)
            Current.styling = thematiq_pdf_styling
            super
          end

          def custom_footer_image
            thematiq_pdf_image(:footer) || super
          end
        end

        module View
          def custom_font_files
            Patches.font_paths(Patches.current_styling) || super
          end

          module ClassMethods
            def valid_custom_font?
              Patches.font_paths(Patches.current_styling) ? true : super
            end
          end
        end
      end
    end
  end
end
