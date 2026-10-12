# frozen_string_literal: true

module Thematiq
  # Keeps the stored token set current. Runs from cron in the worker, never on a page request.
  class RefreshTokensJob < ApplicationJob
    def perform
      OpenProject::Thematiq::Tokens::Refresher.new(store: OpenProject::Thematiq::Store.new).call
    end
  end
end
