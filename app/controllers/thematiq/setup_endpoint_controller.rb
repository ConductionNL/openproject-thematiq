# frozen_string_literal: true

module Thematiq
  # The setup for one other instance to pull (gov-federated-share): the configuration file, as "The whole setup"
  # downloads it. Read only, and off until an administrator turns it on. A bare controller: it reads no session and
  # sets no cookie; the caller names the share key in OpenProject::Thematiq::Federation::KEY_HEADER instead.
  #
  #   off, or no key yet      404, as if the address did not exist
  #   on, key missing/wrong   403
  #   on, key right           200 with the file, never cached
  class SetupEndpointController < ActionController::Metal
    Federation = OpenProject::Thematiq::Federation

    def show
      store = OpenProject::Thematiq::Store.new
      return answer(404) unless store.share_serving_enabled?
      return answer(403) unless Federation.key_matches?(request.headers[Federation::KEY_HEADER].to_s, store.share_key)

      answer(200, OpenProject::Thematiq::Bundle.dump(Thematiq::Change.current_bundle(store)))
    rescue StandardError => e
      Rails.logger.error("[openproject-thematiq] setup endpoint failed: #{e.class}: #{e.message}")
      answer(503)
    end

    private

    def answer(status, body = "")
      headers["Content-Type"] = "application/json; charset=utf-8" if status == 200
      headers["Cache-Control"] = "no-store"
      headers["X-Content-Type-Options"] = "nosniff"
      self.status = status
      self.response_body = body
    end
  end
end
