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
        deleted = custom_id_from_params
        @store.delete_custom(deleted)
        # Its uploaded files go with it. The id is given out again, and the next owner must not inherit them.
        Thematiq::Upload.remove_set(deleted)
        flash[:notice] = t("thematiq.editor.notice_deleted")
        return redirect_to action: :show
      end

      @draft = draft_from_params
      @stored = !@store.custom_draft(@draft.id).nil?
      if params[:preview].present? || params[:reset].present? || params[:reset_all].present?
        flash.now[:notice] = t("thematiq.editor.notice_not_saved")
        render :edit
      elsif save_draft(@draft, new: !@stored)
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

    # The uploaded files of a stored custom design system. One action with two named buttons per form:
    # "upload" stores the chosen file, and for a kind with one file that replaces it. "remove" carries the id
    # of the file to remove. Every upload is hostile input: the Inspector decides what it is by its content.
    def update_files
      id = params[:id].to_s
      return render_404 unless @store.custom_draft(id)

      kind = OpenProject::Thematiq::Uploads.kind(params[:kind])
      raise OpenProject::Thematiq::Uploads::Refused, "not_ready" unless Thematiq::Upload.ready?

      if params[:remove].present?
        removed = Thematiq::Upload.remove(set_id: id, token: params[:remove].to_s)
        raise OpenProject::Thematiq::Uploads::Refused, "not_stored" unless removed.positive?

        flash[:notice] = t("thematiq.uploads.notice_removed")
      else
        raise OpenProject::Thematiq::Uploads::Refused, "unknown_kind" unless kind

        stored = store_upload(id, kind)
        flash[:notice] = t(stored.cleaned ? "thematiq.uploads.notice_stored_cleaned" : "thematiq.uploads.notice_stored",
                           kind: t("thematiq.uploads.kinds.#{kind.name}.label"))
      end
      redirect_to action: :edit, id:
    rescue OpenProject::Thematiq::Uploads::Refused, ActiveRecord::RecordInvalid => e
      code = e.respond_to?(:code) ? e.code : "broken"
      flash[:error] = t("thematiq.uploads.errors.#{upload_error_key(code)}", **upload_limits(kind))
      redirect_to action: :edit, id:
    end

    # Sends one design system as a JSON file in the set shape. Uploaded files stay behind: the file names their kinds.
    def export
      token_set = @store.custom_set(params[:id].to_s) || @store.catalogue.find(params[:id].to_s)
      return render_404 unless token_set

      send_data OpenProject::Thematiq::Transfer.export(token_set, uploads: OpenProject::Thematiq::Assets.uploads_for(token_set)),
                filename: OpenProject::Thematiq::Transfer.file_name(token_set),
                type: "application/json", disposition: "attachment"
    end

    # Reads an uploaded file as a new custom design system. It never replaces one that is there.
    # The file is hostile input: Transfer checks all of it.
    def import
      text = uploaded_text
      imported = OpenProject::Thematiq::Transfer.import(text)
      new_id = @store.next_custom_id
      raise OpenProject::Thematiq::Transfer::Refused, "too_many" unless new_id

      # The file's logo reference is kept. It shows only when it names a logo that ships with the plugin.
      draft = OpenProject::Thematiq::CustomDraft.new(base: @store.catalogue.default, name: imported.name.first(80),
                                                     overrides: imported.tokens, id: new_id,
                                                     logo: { "file" => imported.logo_file, "inverse_file" => imported.logo_inverse_file })
      raise OpenProject::Thematiq::Transfer::Refused, "token_invalid" unless save_draft(draft, new: true)

      left_behind = OpenProject::Thematiq::Transfer.left_behind(text)
      flash[:notice] = if left_behind.any?
                         t("thematiq.transfer.notice_imported_without_files", name: draft.name,
                                                                              kinds: left_behind.map { |kind| t("thematiq.uploads.kinds.#{kind}.label") }.to_sentence)
                       else
                         t("thematiq.transfer.notice_imported", name: draft.name)
                       end
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

    # Stores a draft. A new design system starts without files: whatever a deleted one with the same id
    # may have left in the table is removed first.
    def save_draft(draft, new:)
      Thematiq::Upload.remove_set(draft.id) if new && draft.valid?
      @store.save_custom(draft)
    end

    # At most one byte over the limit of the kind is read. The name the browser sent is kept as a label
    # for the page only. It is never used as a path, a type or a header.
    def store_upload(set_id, kind)
      file = params[:file]
      bytes = file.respond_to?(:read) ? file.read(kind.max_bytes + 1) : nil
      face = if kind.name == "font"
               OpenProject::Thematiq::Uploads::FontFace.clean(family: params[:font_family], weight: params[:font_weight],
                                                              style: params[:font_style])
             end
      result = OpenProject::Thematiq::Uploads::Inspector.inspect_upload(kind.name, bytes)
      Thematiq::Upload.store!(set_id:, result:, face:, label: file.respond_to?(:original_filename) ? file.original_filename.to_s : nil)
      result
    end

    UPLOAD_ERRORS = %w[empty too_large unknown_type wrong_type broken too_small too_wide svg_declares svg_not_svg svg_too_complex
                       font_family_invalid font_weight_invalid font_style_invalid too_many_fonts not_stored not_ready unknown_kind].freeze

    def upload_error_key(code)
      UPLOAD_ERRORS.include?(code) ? code : "broken"
    end

    # The numbers an error message may name.
    def upload_limits(kind)
      return {} unless kind

      { types: kind.formats.map { |format| OpenProject::Thematiq::Uploads::FORMATS.fetch(format)[:label] }.join(", "),
        size: helpers.number_to_human_size(kind.max_bytes), min: kind.min_side, width: kind.max_width, height: kind.max_height,
        count: OpenProject::Thematiq::Uploads::MAX_FONTS }
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
