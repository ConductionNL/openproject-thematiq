# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module Thematiq
    class Engine < ::Rails::Engine
      engine_name :openproject_thematiq

      include OpenProject::Plugins::ActsAsOpEngine

      register "openproject-thematiq",
               author_url: "https://github.com/ConductionNL/openproject-thematiq",
               bundled: false

      config.to_prepare do
        require "open_project/thematiq/hooks"
        require "open_project/thematiq/shell"
        OpenProject::Thematiq::Shell.install!
      end
    end
  end
end
