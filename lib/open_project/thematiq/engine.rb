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
               settings: { default: { "base_url" => "" } } do
        menu :admin_menu,
             :thematiq_design,
             { controller: "/thematiq/admin", action: :show },
             if: ->(_) { User.current.admin? },
             caption: ->(*) { I18n.t("thematiq.admin.menu") },
             icon: "paintbrush"
      end

      config.to_prepare do
        require "open_project/thematiq/store"
        require "open_project/thematiq/hooks"
      end

      add_cron_jobs do
        {
          "Thematiq::RefreshTokensJob": {
            cron: "*/5 * * * *", # every five minutes, with If-None-Match
            class: "Thematiq::RefreshTokensJob"
          }
        }
      end
    end
  end
end
