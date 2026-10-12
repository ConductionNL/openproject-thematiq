# frozen_string_literal: true

module Thematiq
  # The "Thematiq design" page in the administration. Admins only.
  # The fetches it starts are bound by the client's short timeouts.
  class AdminController < ApplicationController
    before_action :require_admin
    before_action :load_state

    layout "admin"
    menu_item :thematiq_design

    def show; end

    # One form posts here with two buttons. Rails binds a CSRF token to one form action,
    # so "Check connection" is a named button on the same action and not a second URL.
    def update
      return check if params[:check].present?

      base_url = params[:base_url].to_s.strip

      if base_url.present? && OpenProject::Thematiq::Tokens::Client.endpoint_for(base_url).nil?
        flash.now[:error] = t("thematiq.errors.invalid_url")
        @base_url = base_url
        return render :show, status: :unprocessable_entity
      end

      changed = base_url != @store.base_url
      @store.forget_token_set if changed
      @store.base_url = base_url

      if base_url.blank?
        flash[:notice] = t("thematiq.admin.notice_saved_without_url")
      else
        report refresher.call(force: true), success: "thematiq.admin.notice_saved_and_fetched"
      end
      redirect_to action: :show
    end

    def refresh
      report refresher.call(force: true), success: "thematiq.admin.notice_refreshed"
      redirect_to action: :show
    end

    private

    # Reads the endpoint for the address in the field and stores nothing.
    def check
      @base_url = params[:base_url].to_s.strip
      outcome = refresher.check(@base_url)

      if outcome.success?
        flash.now[:notice] = t("thematiq.admin.notice_check_ok", name: outcome.token_set.name, revision: outcome.token_set.revision)
      else
        flash.now[:error] = error_message(outcome)
      end
      render :show
    end

    def load_state
      @store = OpenProject::Thematiq::Store.new
      @base_url = @store.base_url
    end

    def refresher
      OpenProject::Thematiq::Tokens::Refresher.new(store: @store)
    end

    def report(outcome, success:)
      if outcome.success?
        flash[:notice] = t(success, name: outcome.token_set.name)
      elsif outcome.status == :not_configured
        flash[:error] = t("thematiq.errors.not_configured")
      else
        flash[:error] = error_message(outcome)
      end
    end

    def error_message(outcome)
      helpers.thematiq_error_message(outcome.error, outcome.detail)
    end
  end
end
