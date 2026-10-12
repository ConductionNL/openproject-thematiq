# frozen_string_literal: true

require "open_project/thematiq/version"

module OpenProject
  # Gives OpenProject the same shell as a Nextcloud themed with thematiq.
  #
  # Layout of this namespace:
  #   OpenProject::Thematiq::Engine  the Rails engine and plugin registration
  #   OpenProject::Thematiq::Hooks   the view hooks (page head)
  #   OpenProject::Thematiq::Shell   reserved for the shared top bar and project menu
  module Thematiq
    ROOT = File.expand_path("../..", __dir__)
    STYLESHEET_DIR = File.join(ROOT, "stylesheets")

    # The CSS the head hook inlines on every page that uses the base layout.
    def self.stylesheet
      @stylesheet ||= Dir[File.join(STYLESHEET_DIR, "*.css")].map { |path| File.read(path) }.join("\n")
    end

    require "open_project/thematiq/engine"
  end
end
