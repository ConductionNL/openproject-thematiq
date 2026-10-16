# frozen_string_literal: true

require "open_project/thematiq/icon_packs"

module OpenProject
  module Thematiq
    # The whole design systems above the colour sets (cat-design-system-choice), as thematiq groups them:
    # NL Design System, La Suite, high contrast, a soft light theme, Cunningham, and none. Which set belongs to
    # which comes from thematiq's token-sets.json, kept in data/icon-packs.json. A set thematiq does not know,
    # such as OpenProject's own themes, belongs to none of them.
    module DesignSystems
      module_function

      def ids
        IconPacks.design_systems.keys
      end

      def known?(id)
        ids.include?(id.to_s)
      end

      def for_set(set_id, base_id: nil)
        IconPacks.token_sets[set_id.to_s] || IconPacks.token_sets[base_id.to_s]
      end
    end
  end
end
