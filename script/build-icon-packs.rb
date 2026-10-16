# frozen_string_literal: true

# Writes frontend/module/icon-pack/targets.ts from data/icon-packs.json: the octicons the frontend module may redraw.
# It also checks that every mapped icon fits an octicon, and stops when one does not.
# Run it after changing the maps: ruby script/build-icon-packs.rb (Ruby of the OpenProject image, see bin/test).
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "open_project/thematiq/icon_packs"

packs = OpenProject::Thematiq::IconPacks
packs.maps.each_key { |pack| packs.build(pack) }
File.write(File.expand_path("../frontend/module/icon-pack/targets.ts", __dir__), packs.targets_source)
packs.maps.each { |pack, map| puts "#{pack}: #{map.size} icons" }
