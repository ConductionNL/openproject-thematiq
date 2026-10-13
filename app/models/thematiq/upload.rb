# frozen_string_literal: true

module Thematiq
  # One uploaded file of a custom design system, with its bytes. The plugin's own table.
  #
  # Only what OpenProject::Thematiq::Uploads::Inspector has passed is ever stored: the controller hands
  # its result to Upload.store!. The rest of the plugin reads records without the bytes.
  class Upload < ApplicationRecord
    self.table_name = "thematiq_uploads"

    Uploads = OpenProject::Thematiq::Uploads
    WITHOUT_BYTES = %i[id token set_id kind file_format byte_size width height sha256 font_family font_weight font_style label].freeze

    validates :token, format: { with: Uploads::TOKEN }, uniqueness: true
    validates :set_id, format: { with: OpenProject::Thematiq::CustomDraft::ID_PATTERN }
    validates :kind, inclusion: { in: Uploads::KINDS.keys }
    validates :file_format, inclusion: { in: Uploads::FORMATS.keys }
    validates :sha256, format: { with: /\A[0-9a-f]{64}\z/ }
    validates :data, presence: true
    validate :format_fits_kind_and_size

    scope :without_bytes, -> { select(*WITHOUT_BYTES) }

    # True once the migration has run. Before that the plugin behaves as if nothing was uploaded.
    # Asked of the database each time, not of the schema cache: right after the migration is rolled back
    # on a running instance the cache still says the table is there, and the editor answered 500
    # (first full test, finding 19). It is one small query.
    def self.ready?
      connection.data_source_exists?(table_name)
    rescue StandardError
      false
    end

    # The files of one custom design system, without their bytes, oldest first.
    def self.records_for(set_id)
      return [] unless set_id.is_a?(String) && ready?

      without_bytes.where(set_id:).order(:id).filter_map(&:to_record)
    end

    # One file by its public id, without its bytes. nil for anything that is not such an id.
    def self.find_record(token)
      return nil unless token.is_a?(String) && Uploads::TOKEN.match?(token) && ready?

      without_bytes.find_by(token:)&.to_record
    end

    # The bytes of one file. Asked for separately, so a request the browser already holds never loads them.
    def self.bytes_for(token)
      return nil unless token.is_a?(String) && Uploads::TOKEN.match?(token)

      where(token:).pick(:data)
    end

    # Stores what the Inspector passed. For a kind with one file per design system it replaces that file.
    # For a font it replaces the file with the same family, weight and style. The new file gets a new id,
    # so the old address stops answering.
    def self.store!(set_id:, result:, label: nil, face: nil)
      kind = Uploads.kind(result.kind)
      transaction do
        scope = where(set_id:, kind: kind.name)
        if kind.single
          scope.delete_all
        else
          scope = scope.where(font_family: face.family, font_weight: face.weight, font_style: face.style)
          scope.delete_all
          raise Uploads::Refused, "too_many_fonts" if where(set_id:, kind: kind.name).count >= Uploads::MAX_FONTS
        end

        create!(token: SecureRandom.hex(32), set_id:, kind: kind.name, file_format: result.format, byte_size: result.byte_size,
                width: result.width, height: result.height, sha256: result.sha256, data: result.bytes,
                font_family: face&.family, font_weight: face&.weight, font_style: face&.style,
                label: OpenProject::Thematiq::Tokens::Validator.label(label.to_s.first(120)))
      end
    end

    # Removes one file of a design system. Returns how many rows went.
    def self.remove(set_id:, token:)
      return 0 unless token.is_a?(String) && Uploads::TOKEN.match?(token)

      where(set_id:, token:).delete_all
    end

    # Removes every file of a design system: when it is deleted, and before its id is given out again.
    def self.remove_set(set_id)
      return 0 unless ready?

      where(set_id:).delete_all
    end

    def to_record
      Uploads::Record.build(token:, set_id:, kind:, format: file_format, byte_size:, width:, height:, sha256:,
                            font_family:, font_weight:, font_style:, label:)
    end

    private

    def format_fits_kind_and_size
      rules = Uploads.kind(kind)
      return if rules.nil?

      errors.add(:file_format, :invalid) unless rules.formats.include?(file_format)
      errors.add(:data, :too_long, count: rules.max_bytes) if data && data.bytesize > rules.max_bytes
      errors.add(:byte_size, :invalid) if data && byte_size != data.bytesize
    end
  end
end
