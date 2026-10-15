#!/usr/bin/env ruby
# frozen_string_literal: true

# Writes docs/contrast-report.md and docs/token-reference.md from the code, without Rails:
#   docker run --rm -v "$PWD":/plugin -w /plugin --entrypoint ruby openproject/openproject:17.9.1 -Ilib script/generate-docs.rb
# test/generated_docs_test.rb fails when the two pages and the code disagree.
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "yaml"
require "open_project/thematiq/catalogue"
require "open_project/thematiq/compliance"

root = File.expand_path("..", __dir__)
hints = YAML.load_file(File.join(root, "config/locales/en.yml")).dig("en", "thematiq", "tokens")
labels = hints.transform_values { |entry| entry["hint"] }
File.write(File.join(root, "docs/contrast-report.md"), OpenProject::Thematiq::Compliance.contrast_document(OpenProject::Thematiq::Catalogue.bundled))
File.write(File.join(root, "docs/token-reference.md"), OpenProject::Thematiq::Compliance.token_document(labels))
puts "Written: docs/contrast-report.md, docs/token-reference.md"
