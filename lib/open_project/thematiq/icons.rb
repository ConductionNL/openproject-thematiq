# frozen_string_literal: true

require "json"

module OpenProject
  module Thematiq
    # thematiq's government icon sets, vendored and rebuilt by the plugin's SVG sanitiser (script/vendor-icons.rb).
    # Any app on the instance uses an icon by name: /thematiq/icons/<set>/<name>.svg, served as a static file.
    module Icons
      INVENTORY = File.expand_path("../../../data/icons.json", __dir__)
      URL_PREFIX = "/thematiq/icons"

      module_function

      def inventory
        @inventory ||= begin
          document = JSON.parse(File.read(INVENTORY))
          document.is_a?(Hash) && document["sets"].is_a?(Hash) ? document.freeze : { "sets" => {} }
        rescue JSON::ParserError, SystemCallError
          { "sets" => {} }
        end
      end

      def sets
        inventory["sets"]
      end

      def url(set, name, root: "")
        entry = sets[set.to_s]
        entry && entry["names"].include?(name.to_s) ? "#{root}#{URL_PREFIX}/#{set}/#{name}.svg" : nil
      end
    end
  end
end
