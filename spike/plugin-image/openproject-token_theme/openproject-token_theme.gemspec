Gem::Specification.new do |s|
  s.name        = "openproject-token_theme"
  s.version     = "0.0.1"
  s.authors     = "Conduction (spike)"
  s.email       = "info@conduction.nl"
  s.homepage    = "https://conduction.nl"
  s.summary     = "OpenProject Token Theme (spike)"
  s.description = "Adds one stylesheet, generated from a design token set, to every OpenProject page."
  s.license     = "GPLv3"
  s.files = Dir["{app,config,lib}/**/*"]
  s.metadata["rubygems_mfa_required"] = "true"
end
