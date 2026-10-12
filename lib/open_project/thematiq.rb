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
    require "open_project/thematiq/contrast"
    require "open_project/thematiq/assets"
    require "open_project/thematiq/variables/generator"
    require "open_project/thematiq/stylesheet"

    # The token set the pages are styled with right now.
    # It never raises. A design plugin must not be the reason a page fails, least of all an error page
    # that is shown because the database is away. Then the default design system is used.
    def self.active_token_set
      Store.new.active_token_set
    rescue StandardError
      Catalogue.bundled.default
    end

    # The CSS the head hook inlines on every page that uses the base layout.
    def self.stylesheet
      Stylesheet.css(active_token_set)
    end

    # The variable layer for the meta hook, which every layout with OpenProject's shared head calls.
    def self.early_stylesheet
      Stylesheet.early_css(active_token_set)
    end

    # The CSS that names files the plugin serves: the fonts and the logo of the active design system.
    # root is the path OpenProject is mounted under, empty when it runs at the top of its host.
    def self.asset_stylesheet(root: "")
      token_set = active_token_set
      assets = Assets.bundled
      logo = assets.logo_url(token_set, root:)
      rules = [assets.font_face_css(token_set, root:)]
      rules << ".op-app-header .op-logo--link { background-image: url(#{logo}); }" if logo
      rules.reject(&:empty?).join("\n")
    end

    require "open_project/thematiq/engine" if defined?(::Rails::Engine)
  end
end
