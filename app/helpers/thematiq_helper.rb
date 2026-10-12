# frozen_string_literal: true

module ThematiqHelper
  KNOWN_ERRORS = %w[invalid_url timeout unreachable http_status invalid_json too_large invalid_payload
                    unexpected_not_modified not_configured].freeze

  # Turns an error code of the token client into a sentence. The detail is only used for the HTTP status.
  def thematiq_error_message(error, detail = nil)
    code = KNOWN_ERRORS.include?(error.to_s) ? error.to_s : "unknown"
    t("thematiq.errors.#{code}", status: detail.to_s[/\A\d{3}\z/] || "?")
  end

  def thematiq_time(time)
    time ? format_time(time) : t("thematiq.admin.never")
  end
end
