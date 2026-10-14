# frozen_string_literal: true

module Thematiq
  # One change to the plugin's setup: the audit entry and the version in one row. See the migration.
  # Append only: a row is never changed or deleted through the model. Change.record is the one way in.
  class Change < ApplicationRecord
    self.table_name = "thematiq_changes"

    # The bundles of this many newest rows are kept, so each can be restored. Older rows keep who, what and when.
    KEEP_VERSIONS = 50
    ACTIONS = %w[apply save_custom delete_custom import figma_upload upload remove_upload shell top_bar scopes project_design
                 trial_publish restore bundle_import environment command_line environment_marker
                 deprecation custom_css own_token].freeze

    validates :action, inclusion: { in: ACTIONS }

    before_update { throw :abort }
    before_destroy { throw :abort }

    def self.ready?
      connection.data_source_exists?(table_name)
    rescue StandardError
      false
    end

    # Writes one row with the setup as it is now. Never raises: a design change must not fail because its history
    # could not be written. Then the log says so.
    def self.record(action, user: User.current, detail: nil, store: OpenProject::Thematiq::Store.new)
      return nil unless ready?

      named = user.respond_to?(:logged?) && user.logged?
      change = create!(action:, user_id: named ? user.id : nil, user_name: named ? user.name.to_s.first(255) : nil,
                       detail: detail.to_s.first(255).presence, bundle: OpenProject::Thematiq::Bundle.dump(current_bundle(store)),
                       created_at: Time.current)
      prune
      change
    rescue StandardError => e
      Rails.logger.warn("[openproject-thematiq] No version was kept of this change (#{action}): #{e.class}: #{e.message}")
      nil
    end

    # The setup as it is now, as a bundle.
    def self.current_bundle(store = OpenProject::Thematiq::Store.new)
      OpenProject::Thematiq::Bundle.build(settings: store.settings_snapshot, scopes: scope_rows,
                                          plugin_version: OpenProject::Thematiq::VERSION)
    end

    def self.scope_rows
      return [] unless Scope.ready?

      identifiers = Project.where(id: Scope.where.not(project_id: nil).select(:project_id)).pluck(:id, :identifier).to_h
      Scope.order(:id).map do |row|
        { project_identifier: row.project_id && identifiers[row.project_id], module_name: row.module_name, design_system_id: row.design_system_id }
      end.reject { |row| row[:project_identifier].nil? && row[:module_name].blank? }
    end

    # Clears the bundles beyond the newest KEEP_VERSIONS. update_all writes past the append only guard on purpose.
    def self.prune
      keep = order(id: :desc).limit(KEEP_VERSIONS).pluck(:id)
      where.not(id: keep).where.not(bundle: nil).update_all(bundle: nil)
    end

    # Makes a checked bundle the setup: the settings, then every choice per project and module. One transaction.
    def self.apply!(checked, store: OpenProject::Thematiq::Store.new)
      transaction do
        store.replace_setup(checked.settings)
        if Scope.ready?
          Scope.delete_all
          ids = Project.where(identifier: checked.scopes.filter_map { |row| row[:project_identifier] }).pluck(:identifier, :id).to_h
          checked.scopes.each do |row|
            Scope.create!(project_id: row[:project_identifier] && ids.fetch(row[:project_identifier]), module_name: row[:module_name],
                          design_system_id: row[:design_system_id])
          end
          RequestStore.delete(:thematiq_scope_rows)
        end
      end
    end

    # The bundle of this version, parsed, or nil when it was cleared.
    def bundle_document
      bundle.present? ? JSON.parse(bundle) : nil
    rescue JSON::ParserError
      nil
    end

    def restorable?
      bundle.present?
    end
  end
end
