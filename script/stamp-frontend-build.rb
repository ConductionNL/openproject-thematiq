# frozen_string_literal: true

# Run by the frontend target of docker/Dockerfile after OpenProject's frontend was rebuilt with the plugin's module.
# Writes frontend-build.json next to the plugin, so the plugin can tell at runtime that its module is in the bundle,
# and for which plugin version and module sources it was built.
require "digest"
require "json"
require "time"

plugin = File.expand_path("..", __dir__)
linked = "/app/frontend/src/app/features/plugins/linked/openproject-thematiq"
manifest = "/app/config/frontend_assets.manifest.json"

abort "The plugin's frontend module is not linked at #{linked}" unless File.symlink?(linked)
abort "OpenProject's frontend manifest is missing at #{manifest}" unless File.file?(manifest)

$LOAD_PATH.unshift File.join(plugin, "lib")
require "open_project/thematiq/frontend_build"

stamp = {
  "plugin_version" => OpenProject::Thematiq::VERSION,
  "openproject_version" => File.read("/app/PRODUCT_VERSION").strip,
  "module_digest" => OpenProject::Thematiq::FrontendBuild.module_digest(File.join(plugin, "frontend/module")),
  "built_at" => Time.now.utc.iso8601
}
File.write(File.join(plugin, "frontend-build.json"), "#{JSON.pretty_generate(stamp)}\n")
puts "Stamped the frontend build: #{stamp.to_json}"
