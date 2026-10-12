# frozen_string_literal: true

# The files an administrator uploads for a custom design system: logos, icons and fonts.
# The bytes are in the table. See docs/uploads.md for why, and for what stays behind when the plugin is removed.
class CreateThematiqUploads < ActiveRecord::Migration[7.1]
  def change
    create_table :thematiq_uploads do |t|
      t.string :token, null: false, limit: 64
      t.string :set_id, null: false, limit: 64
      t.string :kind, null: false, limit: 20
      t.string :file_format, null: false, limit: 10
      t.integer :byte_size, null: false
      t.integer :width
      t.integer :height
      t.string :sha256, null: false, limit: 64
      t.string :font_family, limit: 60
      t.string :font_weight, limit: 7
      t.string :font_style, limit: 6
      t.string :label, limit: 120
      t.binary :data, null: false
      t.timestamps
    end

    add_index :thematiq_uploads, :token, unique: true
    add_index :thematiq_uploads, %i[set_id kind]
  end
end
