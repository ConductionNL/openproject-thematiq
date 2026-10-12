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
      @customs = @query.blank? ? @store.custom_drafts : []
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
    # id names a stored custom design system to edit. from names a design system to start a new one from.
    def edit
      start = @store.catalogue.find(params[:from].to_s)
      @draft = (start ? nil : @store.custom_draft(params[:id].to_s)) ||
               new_draft(start || @store.catalogue.find(@store.active_id) || @store.catalogue.default)
      @stored = !@store.custom_draft(@draft.id).nil?
    end

    # One form posts here with several named buttons. Rails binds a CSRF token to one form action,
    # so preview, reset and delete are buttons on the same action and not URLs of their own.
    def update_custom
      if params[:delete].present?
        @store.delete_custom(custom_id_from_params)
        flash[:notice] = t("thematiq.editor.notice_deleted")
        return redirect_to action: :show
      end

      @draft = draft_from_params
      @stored = !@store.custom_draft(@draft.id).nil?
      if params[:preview].present? || params[:reset].present? || params[:reset_all].present?
        flash.now[:notice] = t("thematiq.editor.notice_not_saved")
        render :edit
      elsif @store.save_custom(@draft)
        @store.activate(@draft.id)
        flash[:notice] = t("thematiq.admin.notice_applied", name: @draft.name)
        redirect_to action: :show
      elsif @draft.valid?
        flash.now[:error] = t("thematiq.transfer.errors.too_many")
        render :edit, status: :unprocessable_entity
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
      token_set = @store.custom_set(params[:id].to_s) || @store.catalogue.find(params[:id].to_s)
      return render_404 unless token_set

      send_data OpenProject::Thematiq::Transfer.export(token_set),
                filename: OpenProject::Thematiq::Transfer.file_name(token_set),
                type: "application/json", disposition: "attachment"
    end

    # Reads an uploaded file as a new custom design system. It never replaces one that is there.
    # The file is hostile input: Transfer checks all of it.
    def import
      imported = OpenProject::Thematiq::Transfer.import(uploaded_text)
      new_id = @store.next_custom_id
      raise OpenProject::Thematiq::Transfer::Refused, "too_many" unless new_id

      # The file's logo reference is kept. It shows only when it names a logo that ships with the plugin.
      draft = OpenProject::Thematiq::CustomDraft.new(base: @store.catalogue.default, name: imported.name.first(80),
                                                     overrides: imported.tokens, id: new_id,
                                                     logo: { "file" => imported.logo_file, "inverse_file" => imported.logo_inverse_file })
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
      %w[empty too_large invalid_json unknown_keys token_invalid name_invalid too_many].include?(code) ? code : "not_a_set"
    end

    def new_draft(base)
      OpenProject::Thematiq::CustomDraft.new(base:, name: t("thematiq.editor.default_name", name: base.name).first(80), overrides: {},
                                             id: @store.next_custom_id || OpenProject::Thematiq::CustomDraft::ID)
    end

    # The id of a stored custom design system, or the id a new one gets. Never an id from outside as it is.
    def custom_id_from_params
      id = params[:id].to_s
      @store.custom_draft(id) ? id : (@store.next_custom_id || OpenProject::Thematiq::CustomDraft::ID)
    end

    def draft_from_params
      base = @store.catalogue.find(params[:based_on].to_s) || @store.catalogue.default
      typed = params[:tokens].respond_to?(:permit) ? params[:tokens].permit(*token_keys).to_h : {}
      typed = {} if params[:reset_all].present?
      typed = typed.except(params[:reset].to_s) if params[:reset].present?
      id = custom_id_from_params
      OpenProject::Thematiq::CustomDraft.new(base:, name: params[:name].to_s, overrides: typed, id:,
                                             logo: @store.custom_draft(id)&.definition&.dig("logo"))
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
