# frozen_string_literal: true

require_relative "lib/open_project/thematiq/version"

Gem::Specification.new do |s|
  s.name        = "openproject-thematiq"
  s.version     = OpenProject::Thematiq::VERSION
  s.authors     = ["Conduction"]
  s.email       = ["info@conduction.nl"]
  s.homepage    = "https://github.com/ConductionNL/openproject-thematiq"
  s.summary     = "Gives OpenProject the same shell as a Nextcloud themed with thematiq"
  s.description = "Reads the active design token set from thematiq and writes it to the CSS variables " \
                  "OpenProject already uses, so both products share one look."
  s.license     = "EUPL-1.2"

  s.required_ruby_version = ">= 3.3"

  s.files = Dir["{app,config,data,lib,public,stylesheets}/**/*", "LICENSE", "README.md"]
  s.require_paths = ["lib"]

  s.metadata["source_code_uri"] = s.homepage
  s.metadata["bug_tracker_uri"] = "#{s.homepage}/issues"
  s.metadata["rubygems_mfa_required"] = "true"
end
