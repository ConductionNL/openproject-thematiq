# frozen_string_literal: true

require "digest"
require "open_project/thematiq/variables/generator"

module OpenProject
  module Thematiq
    # Puts the layers together: the generated variable layer first, then the static files
    # in stylesheets/, in file name order. The result is what the head hook inlines.
    module Stylesheet
      module_function

      # Built once per design system and kept. Projects can each have their own, so a few are live at a time.
      MAX_CACHED = 32

      def css(token_set)
        cached([:page, token_set]) { [Variables::Generator.new(token_set).css, static_layers].reject(&:empty?).join("\n\n") }
      end

      # The variable layer on the content area only, for a module's design system. The static layers read it from there.
      def content_css(token_set)
        cached([:content, token_set]) { Variables::Generator.new(token_set, content: true).css }
      end

      def cached(key)
        digest = Digest::SHA256.hexdigest([key.first, key.last.to_set].to_s)
        @cache ||= {}
        return @cache[digest] if @cache.key?(digest)

        @cache.shift while @cache.size >= MAX_CACHED
        @cache[digest] = yield
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
