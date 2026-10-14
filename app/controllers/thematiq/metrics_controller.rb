# frozen_string_literal: true

module Thematiq
  # GET /thematiq/metrics for a Prometheus scraper. Off by default: without THEMATIQ_METRICS_TOKEN it answers 404,
  # as if it were not there. With it, a request needs "Authorization: Bearer <token>". A bare controller: no session.
  class MetricsController < ActionController::Metal
    def show
      token = OpenProject::Thematiq::Metrics.token
      return answer(404, "") unless token

      given = request.authorization.to_s.delete_prefix("Bearer ")
      return answer(401, "") unless ActiveSupport::SecurityUtils.secure_compare(given, token)

      store = OpenProject::Thematiq::Store.new
      health = OpenProject::Thematiq::Health.report(
        store:, tables: { "uploads" => Upload.ready?, "scopes" => Scope.ready?, "changes" => Change.ready? },
        core_changed: OpenProject::Thematiq::Shell::CoreGuard.changed_files
      )
      counts = { "scopes" => Scope.ready? ? Scope.count : 0, "changes" => Change.ready? ? Change.count : 0 }
      answer(200, OpenProject::Thematiq::Metrics.text(health:, counts:), "text/plain; version=0.0.4; charset=utf-8")
    rescue StandardError => e
      Rails.logger.error("[openproject-thematiq] metrics failed: #{e.class}: #{e.message}")
      answer(503, "")
    end

    private

    def answer(status, body, type = "text/plain; charset=utf-8")
      headers["Content-Type"] = type
      headers["Cache-Control"] = "no-store"
      self.status = status
      self.response_body = body
    end
  end
end
