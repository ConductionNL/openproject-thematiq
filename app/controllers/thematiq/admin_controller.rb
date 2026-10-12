# frozen_string_literal: true

module Thematiq
  # The "Thematiq design" page in the administration. Admins only.
  class AdminController < ApplicationController
    before_action :require_admin
    before_action :load_state

    layout "admin"
    menu_item :thematiq_design

    # The picker: every design system, a search field and the active one.
    def show
      @query = params[:q].to_s.strip.first(100)
      @sets = @store.catalogue.search(@query)
      @custom = @store.custom_draft
    end

    # Makes the chosen design system the active one.
    def update
      token_set = @store.activate(params[:set_id].to_s)

      if token_set
        flash[:notice] = t("thematiq.admin.notice_applied", name: token_set.name)
      else
        flash[:error] = t("thematiq.admin.error_unknown_set")
      end
      redirect_to action: :show
    end

    # The editor: the custom set, or a new one that starts from a design system of the catalogue.
    def edit
      start = @store.catalogue.find(params[:from].to_s)
      @draft = if start
                 new_draft(start)
               else
                 @store.custom_draft || new_draft(@store.catalogue.find(@store.active_id) || @store.catalogue.default)
               end
    end

    # One form posts here with several named buttons. Rails binds a CSRF token to one form action,
    # so preview, reset and delete are buttons on the same action and not URLs of their own.
    def update_custom
      if params[:delete].present?
        @store.delete_custom
        flash[:notice] = t("thematiq.editor.notice_deleted")
        return redirect_to action: :show
      end

      @draft = draft_from_params
      if params[:preview].present? || params[:reset].present? || params[:reset_all].present?
        flash.now[:notice] = t("thematiq.editor.notice_not_saved")
        render :edit
      elsif @store.save_custom(@draft)
        @store.activate(OpenProject::Thematiq::CustomDraft::ID)
        flash[:notice] = t("thematiq.admin.notice_applied", name: @draft.name)
        redirect_to action: :show
      else
        flash.now[:error] = t("thematiq.editor.error_invalid")
        render :edit, status: :unprocessable_entity
      end
    end

    # The Nextcloud address for the app switcher links. Empty is fine: then the switcher shows OpenProject only.
    def update_shell
      if @store.save_nextcloud_url(params[:nextcloud_url])
        flash[:notice] = t(@store.nextcloud_url ? "thematiq.shell.settings.notice_saved" : "thematiq.shell.settings.notice_cleared")
      else
        flash[:error] = t("thematiq.shell.settings.error_invalid")
      end
      redirect_to action: :show
    end

    # Sends one design system as a JSON file in the set shape.
    def export
      token_set = params[:id].to_s == OpenProject::Thematiq::CustomDraft::ID ? @store.custom_set : @store.catalogue.find(params[:id].to_s)
      return render_404 unless token_set

      send_data OpenProject::Thematiq::Transfer.export(token_set),
                filename: OpenProject::Thematiq::Transfer.file_name(token_set),
                type: "application/json", disposition: "attachment"
    end

    # Reads an uploaded file as the custom design system. The file is hostile input: Transfer checks all of it.
    def import
      imported = OpenProject::Thematiq::Transfer.import(uploaded_text)
      draft = OpenProject::Thematiq::CustomDraft.new(base: @store.catalogue.default, name: imported.name.first(80),
                                                     overrides: imported.tokens)
      raise OpenProject::Thematiq::Transfer::Refused, "token_invalid" unless @store.save_custom(draft)

      flash[:notice] = t("thematiq.transfer.notice_imported", name: draft.name)
      redirect_to action: :show
    rescue OpenProject::Thematiq::Transfer::Refused => e
      flash[:error] = t("thematiq.transfer.errors.#{import_error_key(e.code)}")
      redirect_to action: :show
    end

    private

    # At most one byte over the cap is read, so a huge upload is refused without being loaded.
    def uploaded_text
      file = params[:file]
      return nil unless file.respond_to?(:read)

      file.read(OpenProject::Thematiq::Transfer::MAX_BYTES + 1)
    end

    def import_error_key(code)
      %w[empty too_large invalid_json unknown_keys token_invalid name_invalid].include?(code) ? code : "not_a_set"
    end

    def new_draft(base)
      OpenProject::Thematiq::CustomDraft.new(base:, name: t("thematiq.editor.default_name", name: base.name).first(80), overrides: {})
    end

    def draft_from_params
      base = @store.catalogue.find(params[:based_on].to_s) || @store.catalogue.default
      typed = params[:tokens].respond_to?(:permit) ? params[:tokens].permit(*token_keys).to_h : {}
      typed = {} if params[:reset_all].present?
      typed = typed.except(params[:reset].to_s) if params[:reset].present?
      OpenProject::Thematiq::CustomDraft.new(base:, name: params[:name].to_s, overrides: typed)
    end

    def token_keys
      OpenProject::Thematiq::Tokens::TokenSet::KINDS.keys
    end

    def load_state
      @store = OpenProject::Thematiq::Store.new
      # An installation that ran the first version still holds a thematiq address and a fetched token set.
      # They are removed the first time an administrator opens this page.
      @store.remove_legacy_settings
    end
  end
end
