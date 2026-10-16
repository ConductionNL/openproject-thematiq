# frozen_string_literal: true

require "open_project/thematiq/css_comments"

module OpenProject
  module Thematiq
    # Free CSS from an administrator, for what tokens cannot say (thematiq's custom-css-freeform). Hostile input of the
    # highest kind, so this is an allow-list parser, not a pattern that looks for known attacks: the text is read into
    # rules and declarations, each part is checked against what may be in it, and what is stored and served is written
    # anew from the parts. Anything that does not fit refuses the whole submission, with the reasons.
    #
    # What it takes: style rules, and @media blocks around them. Not @import, @font-face, @charset or any other at-rule,
    # no url(), no escapes, no expression(), no markup. Fonts and images come through the uploads, which check content.
    module CustomCss
      MAX_BYTES = 64 * 1024
      MAX_RULES = 1000
      SELECTOR = /\A[A-Za-z0-9_\-\s.#:>+~*\[\]="'(),^$|%]{1,500}\z/
      MEDIA = /\A@media\s+[A-Za-z0-9\s():,.\-]{1,200}\z/
      PROPERTY = /\A(?:--[A-Za-z0-9_-]{1,80}|-?[a-z][a-z0-9-]{0,60})\z/
      VALUE = /\A[A-Za-z0-9\s#%.,()\-+*\/'"!_]{1,500}\z/
      FORBIDDEN_VALUE = /url\s*\(|expression\s*\(|image-set|image\s*\(|element\s*\(|attr\s*\(|javascript:|-moz-binding|behaviou?r/i
      FORBIDDEN_PROPERTY = /\A(?:behaviou?r|-moz-binding|-ms-behavior)\z/i

      Result = Struct.new(:css, :errors, keyword_init: true) do
        def ok?
          errors.empty?
        end
      end

      module_function

      # Returns a Result: the CSS written anew from its checked parts, or the errors (code and the part, cut short).
      def check(text)
        text = text.to_s.dup.force_encoding(Encoding::UTF_8)
        return Result.new(css: "", errors: []) if text.strip.empty?
        return Result.new(css: nil, errors: [["too_large", ""]]) if text.bytesize > MAX_BYTES
        return Result.new(css: nil, errors: [["encoding", ""]]) unless text.valid_encoding?
        return Result.new(css: nil, errors: [["escape", ""]]) if text.include?("\\")
        return Result.new(css: nil, errors: [["markup", ""]]) if text.match?(/[<>]/) && text.match?(%r{</|<\w|<!})

        errors = []
        rules = []
        blocks(CssComments.strip(text), errors) do |prelude, body|
          if prelude.start_with?("@")
            unless MEDIA.match?(prelude)
              errors << ["at_rule", prelude]
              next
            end
            inner = []
            blocks(body, errors) do |selector, declarations|
              if selector.start_with?("@")
                errors << ["nested_at_rule", selector]
              else
                inner << rule(selector, declarations, errors)
              end
            end
            rules << "#{prelude.gsub(/\s+/, ' ')} {\n#{inner.compact.map { |line| "  #{line}" }.join("\n")}\n}"
          else
            rules << rule(prelude, body, errors)
          end
        end
        errors << ["too_many_rules", ""] if rules.size > MAX_RULES
        return Result.new(css: nil, errors: errors.first(50).map { |code, part| [code, part.to_s.strip[0, 80]] }) if errors.any?

        Result.new(css: rules.compact.join("\n"), errors: [])
      end

      # Yields prelude and body of each top-level block. Text outside blocks that is not empty is an error.
      def blocks(css, errors)
        position = 0
        while position < css.length
          open = css.index("{", position)
          unless open
            errors << ["stray_text", css[position..]] unless css[position..].strip.empty?
            break
          end
          prelude = css[position...open].strip
          close = closing(css, open)
          unless close
            errors << ["unclosed", prelude]
            break
          end
          if prelude.empty? || prelude.include?("}") || prelude.include?(";")
            errors << ["selector", prelude]
          else
            yield prelude, css[(open + 1)...close]
          end
          position = close + 1
        end
      end

      def closing(css, open)
        depth = 0
        (open...css.length).each do |index|
          case css[index]
          when "{" then depth += 1
          when "}"
            depth -= 1
            return index if depth.zero?
          end
        end
        nil
      end

      def rule(selector, body, errors)
        selector = selector.gsub(/\s+/, " ")
        unless SELECTOR.match?(selector)
          errors << ["selector", selector]
          return nil
        end
        if body.include?("{")
          errors << ["nested_block", selector]
          return nil
        end

        declarations = body.split(";").map(&:strip).reject(&:empty?).filter_map do |part|
          property, value = part.split(":", 2).map { |piece| piece.to_s.strip }
          if value.nil? || !PROPERTY.match?(property.to_s) || FORBIDDEN_PROPERTY.match?(property.to_s)
            errors << ["property", part]
            next
          end
          if !VALUE.match?(value) || FORBIDDEN_VALUE.match?(value) || value.count("(") != value.count(")") || quotes_open?(value)
            errors << ["value", part]
            next
          end
          "#{property.downcase.start_with?('--') ? property : property.downcase}: #{value.gsub(/\s+/, ' ')};"
        end
        "#{selector} { #{declarations.join(' ')} }"
      end

      def quotes_open?(value)
        value.count('"').odd? || value.count("'").odd?
      end
    end
  end
end
