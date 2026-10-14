# frozen_string_literal: true

module OpenProject
  module Thematiq
    # The plugin's numbers in Prometheus' text format, for a monitoring system. Off unless the operator sets
    # THEMATIQ_METRICS_TOKEN; then a scraper sends it as a bearer token. No user data, no value an administrator typed
    # apart from the id of the design system in use.
    module Metrics
      TOKEN_KEY = "THEMATIQ_METRICS_TOKEN"
      MIN_TOKEN = 24

      module_function

      # The token, or nil when metrics are off. A short token counts as off: it would be guessed.
      def token(env = ENV)
        value = env[TOKEN_KEY].to_s
        value.length >= MIN_TOKEN ? value : nil
      end

      # health: a Health.report. counts: { "changes" => n, "scopes" => n }.
      def text(health:, counts:)
        lines = []
        metric = lambda do |name, help, value, labels = {}|
          lines << "# HELP thematiq_#{name} #{help}"
          lines << "# TYPE thematiq_#{name} gauge"
          label_text = labels.empty? ? "" : "{#{labels.map { |key, label| %(#{key}="#{escape(label)}") }.join(',')}}"
          lines << "thematiq_#{name}#{label_text} #{value}"
        end
        metric.call("info", "The plugin version and the design system in use.", 1,
                    version: health["version"], active: health.dig("active", "id"), from_environment: health.dig("active", "from_environment"))
        metric.call("up", "1 when the health report is ok, 0 when it is degraded.", health["status"] == "ok" ? 1 : 0)
        metric.call("problems", "The number of problems the health report names.", health["problems"].size)
        metric.call("catalogue_sets", "The design systems that ship with the plugin.", health.dig("catalogue", "sets"))
        metric.call("custom_design_systems", "The custom design systems.", health["customs"])
        metric.call("active_rejected_values", "Values of the design system in use that were refused.", health.dig("active", "rejected").size)
        metric.call("scopes", "Design systems chosen per project or module.", counts.fetch("scopes", 0))
        metric.call("changes", "Rows in the history.", counts.fetch("changes", 0))
        metric.call("core_files_changed", "Core files the shell leans on that changed.", health["core_changed"].size)
        "#{lines.join("\n")}\n"
      end

      def escape(value)
        value.to_s.gsub("\\", "\\\\\\\\").gsub("\n", "\\n").gsub('"', '\\"')
      end
    end
  end
end
