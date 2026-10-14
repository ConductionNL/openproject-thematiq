# frozen_string_literal: true

module OpenProject
  module Thematiq
    # A trial: an administrator sees a design system on every page, in their own session, before anyone else does.
    # Everyone else keeps the design system in use. The trial lives in the session, ends after a day, and only counts
    # while the person is an administrator. Publish makes it everyone's, discard ends it.
    module Trial
      KEY = "thematiq_trial"
      SECONDS = 24 * 60 * 60

      module_function

      def start(session, id, now: Time.now)
        session[KEY] = { "id" => id.to_s, "until" => now.to_i + SECONDS }
      end

      def stop(session)
        session.delete(KEY)
      end

      # The id on trial, or nil: none, broken, or past its end.
      def id(session, now: Time.now)
        value = session.respond_to?(:[]) ? session[KEY] : nil
        return nil unless value.is_a?(Hash) && value["id"].is_a?(String) && value["until"].is_a?(Integer)
        return nil if value["until"] <= now.to_i

        value["id"]
      end

      # The design system on trial for this person, or nil. Checked at every page: a person who is no longer an
      # administrator sees what everyone sees.
      def token_set(session:, user:, store:)
        return nil unless user.respond_to?(:admin?) && user.admin?

        trial = id(session)
        trial ? store.find_set(trial) : nil
      rescue StandardError
        nil
      end
    end
  end
end
