# frozen_string_literal: true

require "open_project/thematiq/version"

module OpenProject
  # Gives OpenProject the same shell as a Nextcloud themed with thematiq.
  #
  # Layout of this namespace:
  #   OpenProject::Thematiq::Engine      the Rails engine and plugin registration
  #   OpenProject::Thematiq::Hooks       the view hooks (page head)
  #   OpenProject::Thematiq::Tokens      the token model: token set, validator, last resort values
  #   OpenProject::Thematiq::Catalogue   the design systems that ship with the plugin
  #   OpenProject::Thematiq::Variables   the variable layer: tokens to CSS variables
  #   OpenProject::Thematiq::Stylesheet  the variable layer plus the static layers in stylesheets/
  #   OpenProject::Thematiq::Store       what the plugin keeps in OpenProject's settings
  #   OpenProject::Thematiq::Shell       reserved for the shared top bar and project menu
  module Thematiq
    ROOT = File.expand_path("../..", __dir__)
    STYLESHEET_DIR = File.join(ROOT, "stylesheets")

    require "open_project/thematiq/tokens"
    require "open_project/thematiq/catalogue"
    require "open_project/thematiq/preview"
    require "open_project/thematiq/custom_draft"
    require "open_project/thematiq/transfer"
    require "open_project/thematiq/variables/generator"
    require "open_project/thematiq/stylesheet"

    # The token set the pages are styled with right now.
    def self.active_token_set
      Store.new.active_token_set
    end

    # The CSS the head hook inlines on every page that uses the base layout.
    def self.stylesheet
      Stylesheet.css(active_token_set)
    end

    require "open_project/thematiq/engine" if defined?(::Rails::Engine)
  end
end
