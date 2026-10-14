# frozen_string_literal: true

require_relative "lib/open_project/thematiq/version"

Gem::Specification.new do |s|
  s.name        = "openproject-thematiq"
  s.version     = OpenProject::Thematiq::VERSION
  s.authors     = ["Conduction"]
  s.email       = ["info@conduction.nl"]
  s.homepage    = "https://github.com/ConductionNL/openproject-thematiq"
  s.summary     = "Gives OpenProject the same shell as a Nextcloud themed with thematiq"
  s.description = "Ships the design systems of thematiq and writes the chosen one to the CSS variables OpenProject " \
                  "already uses, with the shared top bar and project menu, so both products share one look. No network unless an administrator turns on the gallery."
  s.license     = "EUPL-1.2"

  s.required_ruby_version = ">= 3.3"

  s.files = Dir["{app,config,data,db,lib,public,stylesheets}/**/*", "LICENSE", "README.md", "CHANGELOG.md"]
  s.require_paths = ["lib"]

  s.metadata["source_code_uri"] = s.homepage
  s.metadata["bug_tracker_uri"] = "#{s.homepage}/issues"
  s.metadata["rubygems_mfa_required"] = "true"
end
