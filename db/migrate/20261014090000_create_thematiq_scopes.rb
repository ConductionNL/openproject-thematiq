# frozen_string_literal: true

# A design system per project and per module. One row per scope: a project or none (a module for the whole
# instance), and a module or "" (every module). The instance's own choice stays in the plugin's settings.
# A deleted project takes its rows with it. See docs/design/scopes.md.
class CreateThematiqScopes < ActiveRecord::Migration[7.1]
  def change
    create_table :thematiq_scopes do |t|
      t.references :project, foreign_key: { on_delete: :cascade }, index: true, null: true
      t.string :module_name, null: false, default: "", limit: 40
      t.string :design_system_id, null: false, limit: 64
      t.timestamps
    end

    # Unique on project and module, the instance-wide module rows (no project) included.
    add_index :thematiq_scopes, "COALESCE(project_id, 0), module_name", unique: true, name: "index_thematiq_scopes_unique"
  end
end
