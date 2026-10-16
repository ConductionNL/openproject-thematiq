# frozen_string_literal: true

module Thematiq
  # The setup shared with one other instance (gov-federated-share): serve this instance's setup, pull another's.
  # For administrators only, not for a brand manager: both sides open the instance to the network. Both are off
  # until turned on here. A pull shows what it changes on the page of a configuration file uploaded by hand, and
  # nothing changes until the administrator confirms there.
  class ShareController < ApplicationController
    before_action :require_admin
    authorization_checked! :show, :update

    layout "admin"
    menu_item :thematiq_design

    def show
      @store = OpenProject::Thematiq::Store.new
    end

    # One form per side, several buttons: save serving, make a new key, save pulling, pull now.
    def update
      @store = OpenProject::Thematiq::Store.new
      if params[:serve].present? || params[:new_key].present?
        @store.save_share_serving(enabled: params[:new_key].present? ? @store.share_serving_enabled? : params[:share_serving_enabled] == "1",
                                  new_key: params[:new_key].present?)
        record_change("share_serving")
        flash[:notice] = t(params[:new_key].present? ? "thematiq.share.notice_new_key" : "thematiq.share.notice_saved")
      elsif params[:save_pull].present?
        if @store.save_share_pull(enabled: params[:share_pull_enabled] == "1", url: params[:share_pull_url], key: params[:share_pull_key])
          record_change("share_pull")
          flash[:notice] = t("thematiq.share.notice_saved")
        else
          flash[:error] = t("thematiq.share.errors.settings")
        end
      elsif params[:pull].present?
        return pull
      end
      redirect_to action: :show
    end

    private

    # Reads the other instance's file and shows what it changes, on the page of a configuration file uploaded by hand.
    # The file is checked here, and again by the confirm on that page, the way a file uploaded by hand is.
    def pull
      @bundle_text = OpenProject::Thematiq::Federation.fetch(@store.share_pull_url, key: @store.share_pull_key, enabled: @store.share_pull_enabled?,
                                                                                   max_bytes: OpenProject::Thematiq::Bundle::MAX_BYTES)
      checked = OpenProject::Thematiq::Bundle.read(@bundle_text.dup.force_encoding(Encoding::UTF_8), catalogue: @store.catalogue,
                                                                                                project_exists: ->(identifier) { Project.exists?(identifier:) })
      @store.record_share_pull
      @changes_list = OpenProject::Thematiq::Bundle.changes(Thematiq::Change.current_bundle(@store), checked)
      @names = design_system_names(checked)
      @pulled_from = @store.share_pull_url
      render "thematiq/admin/bundle_import"
    rescue OpenProject::Thematiq::Gallery::Off
      flash[:error] = t("thematiq.share.errors.pull_off")
      redirect_to action: :show
    rescue OpenProject::Thematiq::Gallery::Refused, OpenProject::Thematiq::Bundle::Refused => e
      @store.record_share_pull(error: e.code)
      flash[:error] = t("thematiq.share.errors.pull", code: e.code.to_s.first(60))
      redirect_to action: :show
    end

    # Design system id to name, from what is here now and from the file, as the hand upload shows them.
    def design_system_names(checked)
      names = @store.all_sets.to_h { |token_set| [token_set.id, token_set.name] }
      (checked.settings["customs"] || {}).each { |id, definition| names[id] ||= definition["name"].to_s }
      names
    end

    # One row of the history. Never fails the action that called it.
    def record_change(action)
      Thematiq::Change.record(action, store: @store)
    end
  end
end
