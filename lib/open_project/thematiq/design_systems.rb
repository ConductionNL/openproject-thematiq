# frozen_string_literal: true

require "json"
require "open_project/thematiq/icon_packs"
require "open_project/thematiq/tokens/validator"

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

      # The documentation addresses of the design systems, from thematiq's design-systems.json ("documentation_url"),
      # kept in data/catalogue/design-systems.json by the nightly catalogue sync.
      DOCUMENTATION_FILE = File.expand_path("../../../data/catalogue/design-systems.json", __dir__)

      def documentation
        @documentation ||= begin
          document = JSON.parse(File.read(DOCUMENTATION_FILE))
          entries = document.is_a?(Hash) && document["documentation"].is_a?(Hash) ? document["documentation"] : {}
          entries.to_h { |id, url| [id.to_s, Tokens::Validator.web_address(url)] }.select { |id, url| url && known?(id) }.freeze
        rescue JSON::ParserError, SystemCallError
          {}.freeze
        end
      end

      # The address of a design system's own documentation, or nil when it names none.
      def documentation_url(id)
        documentation[id.to_s]
      end

      # Where the documentation of a token set is: its own address first, else that of the design system it belongs to.
      def documentation_for(token_set, set_id: token_set.id, base_id: nil)
        token_set.documentation_url || documentation_url(for_set(set_id, base_id:))
      end
    end
  end
end
