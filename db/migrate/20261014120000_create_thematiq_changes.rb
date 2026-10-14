# frozen_string_literal: true

# The history of the plugin's setup: one row per change, who made it and when, and the whole setup after it
# (a bundle, see OpenProject::Thematiq::Bundle). The row is the audit entry and the version in one.
# Rows are never changed or deleted by the plugin; only the bundle of a row older than the newest 50 is cleared,
# so the record of who did what stays and the table stays small. A deleted user keeps their name in the row.
class CreateThematiqChanges < ActiveRecord::Migration[7.1]
  def change
    create_table :thematiq_changes do |t|
      t.string :action, null: false, limit: 40
      t.bigint :user_id, null: true
      t.string :user_name, null: true, limit: 255
      t.string :detail, null: true, limit: 255
      t.text :bundle, null: true
      t.datetime :created_at, null: false
    end

    add_index :thematiq_changes, :created_at
  end
end
