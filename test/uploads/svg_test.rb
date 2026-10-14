# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/uploads"
require_relative "samples"

class UploadsSvgTest < Minitest::Test
  Svg = OpenProject::Thematiq::Uploads::Svg
  Refused = OpenProject::Thematiq::Uploads::Refused

  # What may never be in a rebuilt file, whatever went in.
  FORBIDDEN = [/<script/i, /foreignObject/i, /<iframe/i, /javascript/i, /evil\.example/i, /\son[a-z]+\s*=/i, /<!DOCTYPE/i, /<!ENTITY/i,
               /<\?(?!xml version)/, /@import/i, /expression\(/i, /text\/html/i, /<a[\s>]/, /<set[\s>]/, /<animate/i].freeze

  def clean(name) = Svg.sanitise(UploadSamples.svg(name))

  def refused(text)
    assert_raises(Refused) { Svg.sanitise(text) }.code
  end

  # Every rebuilt file must be well formed and hold only what is on the lists.
  def assert_only_listed(text)
    root = REXML::Document.new(text).root
    waiting = [root]
    until waiting.empty?
      node = waiting.pop
      assert_includes Svg::ELEMENTS, node.name
      node.attributes.each_attribute do |attribute|
        next if attribute.prefix == "xmlns" || attribute.expanded_name == "xmlns"

        assert_includes Svg::ATTRIBUTES + ["href"], attribute.name, attribute.expanded_name
        refute attribute.name.downcase.start_with?("on"), attribute.name
      end
      waiting.concat(node.elements.to_a)
    end
  end

  def test_a_clean_logo_keeps_its_drawing
    result = clean("clean-logo")

    assert_equal 0, result.removed
    assert_includes result.text, %(viewBox="0 0 120 30")
    assert_includes result.text, %(fill="url(#fade)")
    assert_includes result.text, %(clip-path="url(#box)")
    assert_includes result.text, %(xlink:href="#fade")
    assert_includes result.text, ".mark{fill:#aa0055;}"
    assert_includes result.text, "House &amp; style"
    refute_includes result.text, "<!--"
    assert_only_listed(result.text)
  end

  def test_rebuilding_a_rebuilt_file_changes_nothing
    once = clean("clean-logo").text

    assert_equal once, Svg.sanitise(once).text
  end

  def test_a_plain_document_type_is_taken_out_and_the_file_is_kept
    result = clean("doctype-export")

    refute_includes result.text, "DOCTYPE"
    assert_includes result.text, %(d="M0 0h10v10H0z")
  end

  def test_no_allowed_name_is_an_event_handler_or_runs_anything
    assert_empty Svg::ATTRIBUTES.grep(/\Aon/i)
    assert_empty Svg::ELEMENTS & %w[script foreignObject a animate animateTransform animateMotion set iframe object embed audio video feImage metadata switch]
  end

  def test_every_hostile_sample_is_refused_or_comes_out_without_its_payload
    names = UploadSamples.hostile_svg_names

    assert_operator names.size, :>=, 14
    names.each do |name|
      text = begin
        clean(name).text
      rescue Refused
        next
      end
      FORBIDDEN.each { |pattern| refute_match pattern, text, name }
      assert_only_listed(text)
    end
  end

  def test_scripts_are_removed
    result = clean("hostile-script")

    assert_equal 2, result.removed
    assert_includes result.text, "<rect"
  end

  def test_event_handlers_are_removed
    result = clean("hostile-event-handler")

    assert_equal 4, result.removed
    assert_includes result.text, %(<rect width="10" height="10"/>)
  end

  def test_foreign_object_is_removed_with_all_it_holds
    result = clean("hostile-foreign-object")

    assert_equal 1, result.removed
    refute_includes result.text, "body"
  end

  def test_references_that_leave_the_file_are_removed
    text = clean("hostile-external-reference").text

    assert_includes text, %(id="kept")
    refute_includes text, "url("
    refute_includes text, "href"
  end

  def test_javascript_references_are_removed_however_they_are_spelled
    text = clean("hostile-javascript-href").text

    assert_includes text, %(id="kept")
    refute_includes text, "href"
  end

  def test_animation_cannot_bring_a_reference_back
    text = clean("hostile-animation").text

    assert_includes text, %(<use id="u" href="#kept"/>)
  end

  def test_embedded_data_must_be_a_picture_by_its_own_bytes
    text = clean("hostile-data-not-image").text

    refute_includes text, "data:"
    assert_includes clean("embedded-png").text, "data:image/png;base64,iVBOR"
  end

  def test_css_that_reaches_outside_is_removed_and_plain_css_stays
    result = clean("hostile-css")

    refute_includes result.text, "<style"
    assert_includes result.text, %(style="fill: #aa0055")
    assert_equal 7, result.removed
  end

  def test_a_file_that_declares_entities_is_refused_whole
    assert_equal "svg_declares", refused(UploadSamples.svg("hostile-entity-bomb"))
    assert_equal "svg_declares", refused(UploadSamples.svg("hostile-external-entity"))
  end

  def test_a_file_that_draws_itself_many_times_over_is_refused
    assert_equal "svg_too_complex", refused(UploadSamples.svg("hostile-use-bomb"))
    assert_includes clean("hostile-use-loop").text, %(id="kept")
  end

  def test_a_deeply_nested_file_is_refused
    assert_equal "svg_too_complex", refused(%(<svg xmlns="http://www.w3.org/2000/svg">#{'<g>' * 60}#{'</g>' * 60}</svg>))
    assert_equal "svg_too_complex", refused(%(<svg xmlns="http://www.w3.org/2000/svg">#{'<g>' * 30_000}#{'</g>' * 30_000}</svg>))
    assert_equal "svg_too_complex", refused(%(<svg xmlns="http://www.w3.org/2000/svg">#{'<g/>' * 6000}</svg>))
  end

  def test_elements_of_another_namespace_are_removed
    result = clean("hostile-namespace")

    assert_includes result.text, %(<rect id="kept" width="10" height="10"/>)
    assert_equal 1, result.text.scan("<rect").size
  end

  def test_processing_instructions_are_left_out
    text = clean("hostile-processing-instruction").text

    assert_equal 1, text.scan("<?").size
    assert text.start_with?(%(<?xml version="1.0" encoding="UTF-8"?>))
  end

  # First full test, finding 15: the instructions were left out without a word, so the upload said nothing about it.
  def test_processing_instructions_count_as_removed_and_comments_do_not
    assert_equal 2, clean("hostile-processing-instruction").removed, "the xml-stylesheet before the root and the one inside"
    assert_equal 0, clean("clean-logo").removed, "a comment and the XML declaration are not removals"
  end

  def test_text_cannot_close_its_element
    text = clean("hostile-breakout").text

    assert_equal 0, text.scan(/<script/i).size
    assert_includes text, "&lt;script&gt;"
    refute_includes text, "alert(2)"
    assert_only_listed(text)
  end

  def test_files_that_are_not_svg_are_refused
    assert_equal "svg_not_svg", refused(UploadSamples.svg("no-namespace"))
    assert_equal "svg_not_svg", refused(%(<html xmlns="http://www.w3.org/2000/svg"><svg/></html>))
    assert_equal "broken", refused("<svg xmlns='http://www.w3.org/2000/svg'><g></svg>")
    assert_equal "broken", refused("<svg \xFF\xFE".b)
    assert_equal "broken", refused("<svg xmlns='http://www.w3.org/2000/svg'>\x00</svg>")
  end
end
