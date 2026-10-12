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
             if: ->(_) { User.current.admin? },
             caption: ->(*) { I18n.t("thematiq.admin.menu") },
             icon: "paintbrush"
      end

      # Serves the logos and fonts in public/ as plain static files, under /thematiq/.
      # Appended to the stack, so it cannot shadow a route of OpenProject: it only answers for a file that exists.
      initializer "openproject_thematiq.static_files" do |app|
        app.middleware.use ::ActionDispatch::Static, root.join("public").to_s,
                           headers: { "Cache-Control" => "public, max-age=86400" }
      end

      config.to_prepare do
        require "open_project/thematiq/store"
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
