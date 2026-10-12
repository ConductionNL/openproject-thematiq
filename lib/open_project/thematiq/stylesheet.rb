# frozen_string_literal: true

require "digest"
require "open_project/thematiq/variables/generator"

module OpenProject
  module Thematiq
    # Puts the layers together: the generated variable layer first, then the static files
    # in stylesheets/, in file name order. The result is what the head hook inlines.
    module Stylesheet
      module_function

      def css(token_set)
        key = Digest::SHA256.hexdigest(token_set.to_set.to_s)
        @cache ||= {}
        @cache[key] ||= begin
          @cache.clear # one token set is live at a time
          [Variables::Generator.new(token_set).css, static_layers].reject(&:empty?).join("\n\n")
        end
      end

      # The variable layer for the top of the head. It reaches the layouts that do not call the head hook.
      def early_css(token_set)
        Variables::Generator.new(token_set, early: true).css
      end

      def static_layers
        @static_layers ||= Dir[File.join(STYLESHEET_DIR, "**", "*.css")].sort.map { |path| File.read(path) }.join("\n")
      end
    end
  end
end
