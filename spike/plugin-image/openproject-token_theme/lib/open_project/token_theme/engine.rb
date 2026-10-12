require "open_project/plugins"

module OpenProject::TokenTheme
  class Engine < ::Rails::Engine
    engine_name :openproject_token_theme

    include OpenProject::Plugins::ActsAsOpEngine

    register "openproject-token_theme",
             author_url: "https://conduction.nl",
             bundled: false

    config.to_prepare do
      OpenProject::TokenTheme::Hooks
    end
  end
end
