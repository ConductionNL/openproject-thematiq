#!/usr/bin/env ruby
# frozen_string_literal: true

# Fails when a core file the shell depends on differs from the recorded checksum.
# Run it inside an OpenProject image on every OpenProject release:
#
#   docker run --rm --entrypoint ruby <image> /app/custom-plugins/openproject-thematiq/script/check-core.rb
#
# The optional argument is the OpenProject root, /app by default.

require_relative "../lib/open_project/thematiq/shell/core_guard"

guard = OpenProject::Thematiq::Shell::CoreGuard
root = ARGV[0] || "/app"
changed = guard.changed_files(root)

if changed.empty?
  puts "ok: #{guard::FILES.size} core files match OpenProject #{guard::CORE_VERSION}"
else
  warn "These core files differ from OpenProject #{guard::CORE_VERSION}:"
  changed.each { |path| warn "  #{path}" }
  warn "Check each one against lib/open_project/thematiq/shell/, then update core_guard.rb."
  exit 1
end
