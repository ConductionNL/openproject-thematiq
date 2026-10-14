# frozen_string_literal: true

module Thematiq
  # The design system of one project and of each module in it. See docs/design/scopes.md.
  #
  # An instance admin may always open it and choose any design system. A project admin needs the permission
  # "Choose design system" in the project, and the instance admin must have let projects choose. A project admin
  # picks from the list the instance admin allows; a project admin never authors a design system.
  class ProjectDesignController < ApplicationController
    before_action :find_project_by_project_id
    before_action :authorize
    before_action :require_projects_may_choose
    before_action :load_state

    menu_item :settings_thematiq_design

    def show; end

    # One form: the project's own choice and one per module. An empty value inherits.
    def update
      chosen = { "" => params[:design_system].to_s }
      OpenProject::Thematiq::Scopes::MODULES.each_key { |name| chosen[name] = params.dig(:modules, name).to_s }

      # A value the instance admin set may stay, even when it is not on the project's list.
      allowed = ->(module_name, id) { id.empty? || id == @rows[module_name] || @sets.any? { |token_set| token_set.id == id } }
      if chosen.all? { |module_name, id| allowed.call(module_name, id) } && save(chosen)
        Change.record("project_design", detail: @project.identifier, store: @store)
        flash[:notice] = t("thematiq.scopes.project.notice_saved")
      else
        flash[:error] = t("thematiq.scopes.project.error_invalid")
      end
      redirect_to action: :show, project_id: @project.identifier
    end

    private

    def save(chosen)
      Scope.transaction do
        chosen.each do |module_name, id|
          raise ActiveRecord::Rollback unless Scope.choose(project: @project, module_name:, design_system_id: id.presence)
        end
        true
      end
    end

    def require_projects_may_choose
      render_403 unless User.current.admin? || OpenProject::Thematiq::Store.new.projects_may_choose?
    end

    def load_state
      @store = OpenProject::Thematiq::Store.new
      @sets = User.current.admin? ? @store.all_sets : @store.sets_for_projects
      @rows = Scope.rows.select { |row| row.project_id == @project.id }.to_h { |row| [row.module_name, row.design_system_id] }
      @resolution = OpenProject::Thematiq::Scopes.resolve(rows: Scope.rows, chain: OpenProject::Thematiq::PageScope.chain(@project),
                                                         module_name: nil) { |id| @store.find_set(id) }
    end
  end
end
