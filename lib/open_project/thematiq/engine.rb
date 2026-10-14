# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module Thematiq
    class Engine < ::Rails::Engine
      engine_name :openproject_thematiq

      include OpenProject::Plugins::ActsAsOpEngine

      register "openproject-thematiq",
               author_url: "https://github.com/ConductionNL/openproject-thematiq",
               bundled: false,
               settings: { default: {} } do
        menu :admin_menu,
             :thematiq_design,
             { controller: "/thematiq/admin", action: :show },
             if: ->(_) { User.current.admin? || User.current.allowed_globally?(:manage_design) },
             caption: ->(*) { I18n.t("thematiq.admin.menu") },
             icon: "paintbrush"

        menu :project_menu,
             :settings_thematiq_design,
             { controller: "/thematiq/project_design", action: :show },
             parent: :settings,
             caption: ->(*) { I18n.t("thematiq.scopes.project.menu") },
             if: ->(project) {
               (User.current.admin? || OpenProject::Thematiq::Store.new.projects_may_choose?) &&
                 User.current.allowed_in_project?(:choose_design_system, project)
             }
      end

      # Serves the logos and fonts in public/ as plain static files, under /thematiq/.
      # Appended to the stack, so it cannot shadow a route of OpenProject: it only answers for a file that exists.
      initializer "openproject_thematiq.static_files" do |app|
        app.middleware.use ::ActionDispatch::Static, root.join("public").to_s,
                           headers: { "Cache-Control" => "public, max-age=86400" }
      end

      config.to_prepare do
        # A project admin may choose the design system of a project, from the list the instance admin allows,
        # once the instance admin lets projects choose. No role has it until an administrator gives it.
        # Mapped here and not in the register block: OpenProject's access control only loads once the app prepares.
        # A brand manager who is not an administrator: the global permission "Manage the design" opens the whole
        # Thematiq design page, and nothing else of the administration. No role has it until an administrator gives it.
        unless OpenProject::AccessControl.permission(:manage_design)
          OpenProject::AccessControl.map do |map|
            map.permission :manage_design,
                           { "thematiq/admin": ::Thematiq::AdminController.action_methods.map(&:to_sym), admin: %i[index] },
                           permissible_on: :global,
                           require: :loggedin
          end
        end

        unless OpenProject::AccessControl.permission(:choose_design_system)
          OpenProject::AccessControl.map do |map|
            map.project_module nil do
              map.permission :choose_design_system,
                             { "thematiq/project_design": %i[show update] },
                             permissible_on: :project,
                             require: :member
            end
          end
        end

        require "open_project/thematiq/store"
        require "open_project/thematiq/page_scope"
        require "open_project/thematiq/hooks"
        require "open_project/thematiq/shell"
        OpenProject::Thematiq::Shell.install!

        # The uploaded files of a custom design system come from the plugin's table. A page asks several
        # times while it is drawn, so the answer is kept for the length of one request.
        OpenProject::Thematiq::Assets.upload_source = lambda do |set_id|
          RequestStore.fetch([:thematiq_uploads, set_id]) { ::Thematiq::Upload.records_for(set_id) }
        end
      end
    end
  end
end
