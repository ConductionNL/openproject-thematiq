# frozen_string_literal: true

module Thematiq
  # One choice of a design system for a project, a module, or a module in a project. See OpenProject::Thematiq::Scopes.
  class Scope < ApplicationRecord
    self.table_name = "thematiq_scopes"

    belongs_to :project, optional: true

    validates :module_name, format: { with: /\A(?:|[a-z_]{1,40})\z/ }
    validates :design_system_id, presence: true, length: { maximum: 64 }
    validate :module_is_known, :not_the_instance

    # Every row as the plain rows the rules read, once per request.
    def self.rows
      RequestStore.fetch(:thematiq_scope_rows) do
        ready? ? pluck(:project_id, :module_name, :design_system_id).map { |p, m, d| OpenProject::Thematiq::Scopes::Row.new(project_id: p, module_name: m, design_system_id: d) } : []
      end
    end

    # Whether the migration has run. Before it, every page uses the instance's design system.
    def self.ready?
      connection.table_exists?(table_name)
    rescue ActiveRecord::ActiveRecordError
      false
    end

    # Sets or clears one choice. An empty or nil id clears it, so the scope inherits again.
    def self.choose(project:, module_name:, design_system_id:)
      scope = find_or_initialize_by(project_id: project&.id, module_name: module_name.to_s)
      return scope.persisted? ? scope.destroy : true if design_system_id.blank?

      scope.design_system_id = design_system_id
      scope.save
    ensure
      RequestStore.delete(:thematiq_scope_rows)
    end

    private

    def module_is_known
      return if module_name.blank? || OpenProject::Thematiq::Scopes::MODULES.key?(module_name)

      errors.add(:module_name, :inclusion)
    end

    # The instance's own choice is the plugin setting, never a row.
    def not_the_instance
      errors.add(:module_name, :blank) if project_id.nil? && module_name.blank?
    end
  end
end
