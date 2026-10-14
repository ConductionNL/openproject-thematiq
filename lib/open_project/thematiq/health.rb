# frozen_string_literal: true

require "open_project/thematiq/version"

module OpenProject
  module Thematiq
    # What a monitoring system or an administrator asks: does the plugin work, and if not, what is wrong.
    # The parts that need Rails are handed in, so this runs in a unit test too.
    module Health
      module_function

      # tables: name to true or false (the migration ran). core_changed: core files the shell leans on that changed.
      def report(store:, tables:, core_changed:)
        catalogue = store.catalogue
        active = store.active_token_set
        problems = []
        problems << "catalogue_unusable" if catalogue.error
        problems << "catalogue_skipped" if catalogue.skipped.to_i.positive?
        problems << "active_rejected" if active.rejected.any?
        tables.each { |name, ready| problems << "table_missing:#{name}" unless ready }
        problems << "core_changed" if core_changed.any?
        problems << "environment_unknown" if store.environment_value && !store.environment_id

        { "status" => problems.empty? ? "ok" : "degraded", "problems" => problems, "version" => VERSION,
          "catalogue" => { "sets" => catalogue.sets.size, "skipped" => catalogue.skipped.to_i, "error" => !catalogue.error.nil? },
          "active" => { "id" => active.id, "name" => active.name, "custom" => store.custom_active?, "rejected" => active.rejected,
                        "from_environment" => !store.environment_id.nil? },
          "customs" => store.custom_drafts.size, "tables" => tables, "core_changed" => core_changed }
      end
    end
  end
end
