# frozen_string_literal: true

require "open_project/thematiq/scopes"
require "open_project/thematiq/trial"

module OpenProject
  module Thematiq
    # The design systems of the page being drawn: the one of the whole page and the one of its content.
    # Worked out once per request, from the page's project and its current menu item, by the rules of Scopes.
    # The head hooks call it first; everything after them in the same request asks PageScope.current.
    module PageScope
      Result = Struct.new(:page_set, :content_set, :resolution, :module_name, keyword_init: true) do
        # The content's design system when it is not the page's, else nil.
        def content_only_set
          resolution.split? ? content_set : nil
        end
      end

      module_function

      def for(project:, controller:)
        RequestStore.fetch(:thematiq_page_scope) { compute(project:, controller:) }
      end

      def current
        RequestStore.store[:thematiq_page_scope]
      end

      # Never raises: a design plugin must not be the reason a page fails. Then the instance's design system is used.
      def compute(project:, controller:, store: Store.new)
        instance = store.active_token_set
        module_name = Scopes.module_of(menu_item(controller))
        # A trial wins everywhere, for the administrator who started it. Nobody else has it in their session.
        trial = Trial.token_set(session: session_of(controller), user: current_user, store:)
        if trial
          source = [trial.id, TRIAL]
          return Result.new(page_set: trial, content_set: trial, resolution: Scopes::Resolution.new(page: source, content: source), module_name:)
        end

        resolution = Scopes.resolve(rows: ::Thematiq::Scope.rows, chain: chain(project), module_name:) { |id| store.find_set(id) }
        page = store.find_set(resolution.page.first) || instance
        Result.new(page_set: page, content_set: store.find_set(resolution.content.first) || instance, resolution:, module_name:)
      rescue StandardError => e
        Rails.logger.error("[openproject-thematiq] The design system of this page fell back to the instance's: #{e.class}: #{e.message}")
        fallback = Catalogue.bundled.default
        Result.new(page_set: fallback, content_set: fallback, resolution: Scopes::Resolution.new(page: [nil, Scopes::INSTANCE], content: [nil, Scopes::INSTANCE]))
      end

      TRIAL = Scopes::Source.new(kind: :trial).freeze

      def trial?
        current&.resolution&.page&.last == TRIAL
      end

      def session_of(controller)
        controller.respond_to?(:session) ? controller.session : nil
      rescue StandardError
        nil
      end

      def current_user
        defined?(::User) ? ::User.current : nil
      end

      # The project and its ancestors, nearest first. Nothing outside a project.
      def chain(project)
        return [] unless project.respond_to?(:persisted?) && project.persisted?

        project.self_and_ancestors.reorder(lft: :desc).pluck(:id)
      end

      def menu_item(controller)
        controller.respond_to?(:current_menu_item, true) ? controller.send(:current_menu_item) : nil
      rescue StandardError
        nil
      end
    end
  end
end
