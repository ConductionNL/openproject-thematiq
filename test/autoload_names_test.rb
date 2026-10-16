# frozen_string_literal: true

require "test_helper"

# OpenProject loads the plugin with Zeitwerk and inflects "api" as the acronym "API". A file named read_api.rb must
# define ReadAPI, or OpenProject does not start in production (found live: the web process exited on boot).
class AutoloadNamesTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  # OpenProject's config/initializers/zeitwerk.rb: "pdf" is "PDF" as well, so pdf_export.rb defines PDFExport.
  ACRONYMS = { "api" => "API", "pdf" => "PDF" }.freeze

  def expected_constant(path)
    File.basename(path, ".rb").split("_").map { |part| ACRONYMS.fetch(part) { part.capitalize } }.join
  end

  def test_every_file_defines_the_constant_its_name_gives
    files = Dir[File.join(ROOT, "lib/open_project/thematiq/**/*.rb")] + Dir[File.join(ROOT, "app/{controllers,models,helpers}/**/*.rb")]
    files.each do |path|
      # version.rb holds a constant of the Thematiq module, required by the gemspec; it boots today as it is.
      next if path.end_with?("/thematiq/version.rb")

      text = File.read(path)
      # A file of requires only, such as tokens.rb, defines nothing of its own.
      next unless text.match?(/^\s*(?:class|module) /)

      name = expected_constant(path)
      assert_match(/^\s*(?:(?:class|module) (?:\w+::)*#{name}\b|#{name} = )/, text, "#{path.delete_prefix(ROOT)} must define #{name}")
    end
  end
end
