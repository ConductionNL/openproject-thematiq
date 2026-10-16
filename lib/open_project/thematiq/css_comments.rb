# frozen_string_literal: true

module OpenProject
  module Thematiq
    # Takes the comments out of CSS in one pass. Each closed /* ... */ becomes one space; an unclosed comment stays as
    # it is, for the parser after it to refuse. Linear in the length of the text, whatever the text holds.
    module CssComments
      module_function

      def strip(text)
        text = text.to_s
        out = +""
        position = 0
        while (start = text.byteindex("/*", position))
          finish = text.byteindex("*/", start + 2)
          break unless finish

          out << text.byteslice(position, start - position) << " "
          position = finish + 2
        end
        out << text.byteslice(position, text.bytesize - position)
        out.force_encoding(text.encoding)
      end
    end
  end
end
