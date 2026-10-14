#!/usr/bin/env ruby
# frozen_string_literal: true

# Vendors thematiq's government icon sets into public/thematiq/icons/ (ast-icon-library). Every file is rebuilt by the
# plugin's own SVG sanitiser, as an upload would be; a file it cannot rebuild is left out and named. The inventory,
# with each set's licence and source, goes to data/icons.json.
#
#   ruby -Ilib script/vendor-icons.rb <directory with thematiq's img/icons> <thematiq commit>
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "json"
require "fileutils"
require "open_project/thematiq/uploads"

SETS = {
  "rvo" => { "licence" => "CC0-1.0", "source" => "RVO / ROOS (Rijksdienst voor Ondernemend Nederland)" },
  "open-gemeenten" => { "licence" => "CC0-1.0", "source" => "OpenGemeenten Iconenset, line style" },
  "den-haag" => { "licence" => "EUPL-1.2", "source" => "Gemeente Den Haag icon set" },
  "dsfr" => { "licence" => "Etalab-2.0", "source" => "Système de Design de l'État (DSFR), @gouvfr/dsfr" }
}.freeze
NAME = /\A[a-z0-9][a-z0-9-]{0,120}\z/

source, commit = ARGV
abort "usage: vendor-icons.rb <img/icons directory> <thematiq commit>" unless source && commit && File.directory?(source)

root = File.expand_path("..", __dir__)
target = File.join(root, "public", "thematiq", "icons")
FileUtils.rm_rf(target)
inventory = { "source" => "thematiq development #{commit}, img/icons", "sets" => {} }
left_out = []
SETS.each do |set, meta|
  names = []
  Dir[File.join(source, set, "*.svg")].sort.each do |path|
    name = File.basename(path, ".svg")
    next left_out << "#{set}/#{name}: name" unless NAME.match?(name)

    begin
      clean, = OpenProject::Thematiq::Uploads::Svg.sanitise(File.binread(path))
    rescue OpenProject::Thematiq::Uploads::Refused => e
      next left_out << "#{set}/#{name}: #{e.code}"
    end
    FileUtils.mkdir_p(File.join(target, set))
    File.binwrite(File.join(target, set, "#{name}.svg"), clean)
    names << name
  end
  inventory["sets"][set] = meta.merge("count" => names.size, "names" => names)
end
File.write(File.join(root, "data", "icons.json"), "#{JSON.pretty_generate(inventory)}\n")
puts "Vendored #{inventory['sets'].values.sum { |entry| entry['count'] }} icons; left out #{left_out.size}"
left_out.first(50).each { |line| puts "  #{line}" }
