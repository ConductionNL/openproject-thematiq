# frozen_string_literal: true

module Thematiq
  # thematiq's shell-tokens endpoint, in the same shape: the active house style as eighteen values and a logo.
  # No session, like thematiq's: the values are what every visitor of the sign-in page already gets as CSS.
  # A bare controller, like FilesController: it reads no session and sets no cookie.
  class ShellTokensController < ActionController::Metal
    def show
      store = OpenProject::Thematiq::Store.new
      token_set = store.active_token_set
      assets = OpenProject::Thematiq::Assets.bundled
      base = "#{request.base_url}#{OpenProject::Configuration['rails_relative_url_root']}"
      logo = assets.logo_variant_url(token_set, "logo", root: base)
      inverse = assets.logo_variant_url(token_set, "logo_inverse", root: base)
      body = OpenProject::Thematiq::ReadApi.shell_tokens(token_set, logo_urls: [logo.presence, inverse.presence])
      headers["Content-Type"] = "application/json; charset=utf-8"
      headers["Cache-Control"] = "public, max-age=60"
      headers["X-Content-Type-Options"] = "nosniff"
      self.status = 200
      self.response_body = JSON.generate(body)
    rescue StandardError => e
      Rails.logger.error("[openproject-thematiq] shell-tokens failed: #{e.class}: #{e.message}")
      self.status = 503
      self.response_body = ""
    end
  end
end
