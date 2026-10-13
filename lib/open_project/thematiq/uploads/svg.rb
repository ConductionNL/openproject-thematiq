# frozen_string_literal: true

require "rexml/document"
require "base64"

module OpenProject
  module Thematiq
    module Uploads
      # Rebuilds an uploaded SVG file from an allow-list.
      #
      # The uploaded text is parsed, and a new file is written from the parts on the lists below. Nothing of
      # the upload is copied through as text: every element name, attribute name and value in the result was
      # written by this class, escaped. So what is not on a list is not in the result, whatever it was.
      #
      # Not on the lists, and so removed: script, foreignObject, a, every animation element, every attribute
      # that starts with "on", every reference that leaves the file, and embedded data that is not a picture.
      # A file with a document type that declares anything, or with an entity declaration, is refused whole.
      module Svg
        Sanitised = Struct.new(:text, :removed, keyword_init: true)

        NAMESPACE = "http://www.w3.org/2000/svg"
        XLINK = "http://www.w3.org/1999/xlink"
        MAX_NODES = 5000
        MAX_DEPTH = 40
        MAX_DRAWN = 50_000

        ELEMENTS = %w[
          svg g defs symbol use path rect circle ellipse line polyline polygon text tspan textPath title desc
          linearGradient radialGradient stop clipPath mask pattern marker image style
          filter feBlend feColorMatrix feComponentTransfer feComposite feFlood feGaussianBlur feMerge feMergeNode
          feMorphology feOffset feDropShadow feFuncR feFuncG feFuncB feFuncA
        ].freeze

        ATTRIBUTES = %w[
          id class style x y x1 y1 x2 y2 cx cy r rx ry fx fy d points width height viewBox preserveAspectRatio
          transform fill fill-opacity fill-rule stroke stroke-width stroke-linecap stroke-linejoin stroke-miterlimit
          stroke-dasharray stroke-dashoffset stroke-opacity opacity color display visibility overflow clip-path
          clip-rule mask filter marker-start marker-mid marker-end font-family font-size font-weight font-style
          font-variant text-anchor dominant-baseline alignment-baseline baseline-shift letter-spacing word-spacing
          text-decoration dx dy rotate textLength lengthAdjust startOffset offset stop-color stop-opacity
          gradientUnits gradientTransform spreadMethod patternUnits patternContentUnits patternTransform
          clipPathUnits maskUnits maskContentUnits markerWidth markerHeight markerUnits refX refY orient version
          in in2 result stdDeviation mode type values operator k1 k2 k3 k4 flood-color flood-opacity radius
          tableValues slope intercept amplitude exponent filterUnits primitiveUnits color-interpolation-filters
          vector-effect paint-order shape-rendering text-rendering image-rendering mix-blend-mode isolation
          role aria-label aria-hidden
        ].freeze

        # Elements whose text is kept. Everywhere else text is layout whitespace and is dropped.
        TEXT_ELEMENTS = %w[text tspan textPath title desc style].freeze
        # Elements that may point at another part of the same file.
        REFERENCING = %w[use linearGradient radialGradient pattern textPath filter image].freeze

        ID = /\A[A-Za-z0-9_.:-]{1,200}\z/
        FRAGMENT = /\A#[A-Za-z0-9_.:-]{1,200}\z/
        LOCAL_URL = /url\(\s*(?:'#[A-Za-z0-9_.:-]{1,200}'|"#[A-Za-z0-9_.:-]{1,200}"|#[A-Za-z0-9_.:-]{1,200})\s*\)/
        # What a value may never hold, once the references to the file itself are taken out.
        UNSAFE_VALUE = /url\s*\(|javascript\s*:|data\s*:|expression\s*\(|@import|@font-face|\\|[\x00-\x08\x0B\x0C\x0E-\x1F]/i
        EMBEDDED_IMAGE = %r{\Adata:image/(png|jpeg|webp);base64,([A-Za-z0-9+/=\s]+)\z}
        PLAIN_DOCTYPE = /<!DOCTYPE[^\[<>]*>/i

        module_function

        # True when the bytes are text that starts like an SVG file. The sanitiser decides the rest.
        def looks_like_svg?(bytes)
          text = bytes.dup.force_encoding(Encoding::UTF_8)
          return false unless text.valid_encoding? && !text.include?("\x00")

          head = text[0, 2000].delete_prefix("﻿").lstrip
          head.start_with?("<?xml", "<svg", "<!--", "<!DOCTYPE svg") && text.include?("<svg")
        end

        # Returns the rebuilt file and how many parts were left out. Raises Refused for a file it cannot rebuild.
        def sanitise(bytes)
          text = bytes.dup.force_encoding(Encoding::UTF_8)
          raise Refused, "broken" unless text.valid_encoding? && !text.include?("\x00")

          # A document type without declarations of its own is common in older exports and harmless. It is taken out.
          # Anything else that declares is refused: that is where entities come from.
          text = text.delete_prefix("﻿").sub(PLAIN_DOCTYPE, "")
          raise Refused, "svg_declares" if text.match?(/<!DOCTYPE|<!ENTITY|<!ELEMENT|<!ATTLIST/i)

          root = parse(text)
          raise Refused, "svg_not_svg" unless root && root.name == "svg" && root.namespace == NAMESPACE

          ids = {}
          count = 0
          # Walked with a list and not by calling itself, so a file nested a hundred thousand deep is refused
          # here and cannot run the process out of stack further on.
          waiting = [[root, 0]]
          until waiting.empty?
            node, depth = waiting.pop
            raise Refused, "svg_too_complex" if (count += 1) > MAX_NODES || depth > MAX_DEPTH

            ids[node.attributes["id"]] ||= node if node.attributes["id"]
            node.elements.each { |child| waiting << [child, depth + 1] }
          end
          drawn_size(root, ids, {}, [])

          state = { nodes: 0, removed: 0 }
          body = element(root, 0, state)
          raise Refused, "svg_not_svg" if body.nil?

          Sanitised.new(text: %(<?xml version="1.0" encoding="UTF-8"?>\n#{body}\n), removed: state[:removed])
        end

        def parse(text)
          REXML::Document.new(text).root
        rescue REXML::ParseException, RuntimeError, ArgumentError
          raise Refused, "broken"
        end

        # One element, rebuilt. nil when the element is not on the list: it is left out with all it holds.
        def element(node, depth, state)
          state[:nodes] += 1
          raise Refused, "svg_too_complex" if state[:nodes] > MAX_NODES || depth > MAX_DEPTH

          unless node.namespace == NAMESPACE && node.prefix.to_s.empty? && ELEMENTS.include?(node.name)
            state[:removed] += 1
            return nil
          end

          children = node.children.filter_map { |child| child_markup(node, child, depth, state) }
          if node.name == "style" && !children.all? { |css| safe_css?(unescape(css)) }
            state[:removed] += 1
            return nil
          end

          attributes = attributes_of(node, state)
          attributes.unshift(%(xmlns="#{NAMESPACE}"), %(xmlns:xlink="#{XLINK}")) if depth.zero?
          opening = ([node.name] + attributes).join(" ")
          children.empty? ? "<#{opening}/>" : "<#{opening}>#{children.join}</#{node.name}>"
        end

        def child_markup(parent, child, depth, state)
          case child
          when REXML::Element
            element(child, depth + 1, state)
          when REXML::Text
            text = child.value
            TEXT_ELEMENTS.include?(parent.name) && !text.strip.empty? ? escape(text) : nil
          else
            # Comments, processing instructions and anything else are left out. They are not counted as removed.
            nil
          end
        end

        def attributes_of(node, state)
          node.attributes.each_attribute.filter_map do |attribute|
            next nil if attribute.prefix == "xmlns" || attribute.expanded_name == "xmlns"

            written = attribute_markup(node, attribute)
            state[:removed] += 1 unless written
            written
          end
        end

        def attribute_markup(node, attribute)
          name = attribute.name
          value = attribute.value.to_s
          xlink = attribute.prefix == "xlink" && attribute.namespace == XLINK

          if name == "href" && (xlink || attribute.prefix.to_s.empty?)
            return nil unless REFERENCING.include?(node.name) && safe_reference?(node, value)

            return %(#{xlink ? 'xlink:href' : 'href'}="#{escape(value.gsub(/\s+/, ''))}")
          end
          return nil unless attribute.prefix.to_s.empty? && ATTRIBUTES.include?(name)
          return nil if name == "id" && !ID.match?(value)
          return nil unless name == "style" ? safe_css?(value) : safe_value?(value)

          %(#{name}="#{escape(value)}")
        end

        # A reference may point into the file itself. An image may also hold a PNG, JPEG or WebP picture as data,
        # and then the data must be that kind of picture by its own first bytes.
        def safe_reference?(node, value)
          return true if FRAGMENT.match?(value)
          return false unless node.name == "image"

          match = EMBEDDED_IMAGE.match(value)
          return false unless match

          Inspector.sniff(Base64.decode64(match[2]).b) == match[1]
        end

        def safe_value?(value)
          !UNSAFE_VALUE.match?(value.gsub(LOCAL_URL, ""))
        end

        # CSS gets the same check as any value, on the text as it is. Comments are not taken out first:
        # a comment mark inside a quoted string would then hide what follows it from the check.
        def safe_css?(css)
          safe_value?(css)
        end

        # How many elements the file draws once every "use" is followed. A handful of elements that each use
        # the one before twice draw millions, so the count is taken before anything is rebuilt.
        def drawn_size(node, ids, memo, path)
          return 0 if path.include?(node)
          return memo[node] if memo.key?(node)

          inner = path + [node]
          size = 1 + node.elements.sum { |child| drawn_size(child, ids, memo, inner) }
          target = node.name == "use" ? ids[(node.attributes["href"] || node.attributes["xlink:href"]).to_s.delete_prefix("#")] : nil
          size += drawn_size(target, ids, memo, inner) if target
          raise Refused, "svg_too_complex" if size > MAX_DRAWN

          memo[node] = size
        end

        def escape(text)
          text.gsub(/[&<>"']/, "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", '"' => "&quot;", "'" => "&#39;")
        end

        def unescape(text)
          text.gsub(/&(amp|lt|gt|quot|#39);/) { { "amp" => "&", "lt" => "<", "gt" => ">", "quot" => '"', "#39" => "'" }[Regexp.last_match(1)] }
        end
      end
    end
  end
end
