# frozen_string_literal: true

module Thematiq
  # Read endpoints for other apps on this OpenProject: the catalogue for a picker of their own, one design system,
  # its style sheets in cascade order, and a contrast check. For anyone signed in; no administrator rights needed.
  # Nothing here writes. See docs/api.md.
  class APIController < ApplicationController
    before_action :require_login
    authorization_checked! :sets, :set, :stylesheet, :manifest, :contrast, :deprecations, :own_tokens

    # Every design system there is, custom ones first, and which one is in use.
    def sets
      store = OpenProject::Thematiq::Store.new
      active = store.active_token_set.id
      customs = store.custom_drafts.map(&:id)
      render json: { "version" => OpenProject::Thematiq::ReadAPI::VERSION,
                     "sets" => store.all_sets.map { |set| OpenProject::Thematiq::ReadAPI.summary(set, active_id: active, custom: customs.include?(set.id)) } }
    end

    # One design system in the set shape, as an export holds it.
    def set
      token_set = find_set
      return head :not_found unless token_set

      render json: token_set.to_set
    end

    # The plugin's whole style sheet for one design system, the variable layer first.
    def stylesheet
      token_set = find_set
      return head :not_found unless token_set

      css = [OpenProject::Thematiq::Stylesheet.css(token_set),
             OpenProject::Thematiq::Assets.bundled.font_face_css(token_set, root: relative_root)].reject(&:blank?).join("\n\n")
      response.headers["X-Content-Type-Options"] = "nosniff"
      render plain: css, content_type: "text/css"
    end

    # The style sheets a page needs to wear one design system, in cascade order, to swap them in place.
    def manifest
      token_set = find_set
      return head :not_found unless token_set

      render json: { "version" => OpenProject::Thematiq::ReadAPI::VERSION, "id" => token_set.id,
                     "stylesheets" => [{ "url" => thematiq_api_stylesheet_url(id: token_set.id), "media" => "all",
                                         "replaces" => %w[openproject-thematiq openproject-thematiq-assets] }] }
    end

    # The contrast of two colours, the way the plugin measures it.
    def contrast
      render json: OpenProject::Thematiq::ReadAPI.contrast(params[:foreground], params[:background])
    end

    # Every deprecated token: what to use instead and by when. due: the date has passed. No user data.
    def deprecations
      list = OpenProject::Thematiq::Store.new.deprecations.map do |entry|
        entry.merge("css_name" => css_name(entry["key"]), "replacement_css_name" => entry["replacement"] && css_name(entry["replacement"]))
      end
      render json: { "version" => OpenProject::Thematiq::ReadAPI::VERSION, "deprecations" => list }
    end

    # The organisation's own tokens: name, CSS name, kind, value and dark value.
    def own_tokens
      render json: { "version" => OpenProject::Thematiq::ReadAPI::VERSION, "own_tokens" => OpenProject::Thematiq::Store.new.own_tokens }
    end

    private

    def css_name(key)
      OpenProject::Thematiq::Tokens::Vocabulary.key?(key) ? OpenProject::Thematiq::Tokens::Vocabulary.css_name(key) : "--thematiq-#{key == 'font-family' ? 'font' : key}"
    end

    def find_set
      OpenProject::Thematiq::Store.new.find_set(params[:id].to_s)
    end

    def relative_root
      OpenProject::Configuration["rails_relative_url_root"].to_s
    end
  end
end
