# frozen_string_literal: true

module Thematiq
  # The "Thematiq design" page in the administration. For administrators, and for a brand manager with the global
  # permission "Manage the design" (gov-delegated-role).
  class AdminController < ApplicationController
    before_action :authorize_global
    before_action :load_state

    layout "admin"
    menu_item :thematiq_design

    # The picker: every design system, a search field and the active one.
    def show
      # The catalogue notice checks once a day, on this page, when an administrator turned the gallery on.
      check_gallery if @store.gallery_enabled? && OpenProject::Thematiq::Gallery.due?(@store.gallery_status["checked_at"])
      @query = params[:q].to_s.strip.first(100)
      @sets = @store.catalogue.search(@query)
      @customs = @store.custom_drafts(@query)
      # A whole design system narrows the list to its sets (cat-design-system-choice).
      @design_system = OpenProject::Thematiq::DesignSystems.known?(params[:ds]) ? params[:ds].to_s : nil
      if @design_system
        systems = OpenProject::Thematiq::DesignSystems
        @sets = @sets.select { |set| systems.for_set(set.id) == @design_system }
        @customs = @customs.select { |custom| systems.for_set(custom.id, base_id: custom.base.id) == @design_system }
      end
      @total = @store.catalogue.sets.size + @store.custom_drafts.size
    end

    # What changes when the chosen design system replaces the one in use, before anything is applied.
    # Every value that differs, light and dark, each with a box to keep the value of now. Also the way to a trial.
    def compare
      @chosen = @store.find_set(params[:set_id].to_s)
      return refuse_unknown_set unless @chosen

      @current = @store.active_token_set
      if @chosen.id == current_id && OpenProject::Thematiq::Trial.id(session).nil?
        flash[:notice] = t("thematiq.compare.notice_same", name: @chosen.name)
        return redirect_to action: :show
      end

      @rows = OpenProject::Thematiq::Diff.between(@current, @chosen)
    end

    # Makes the chosen design system the active one. After the comparison, the values left unticked are kept: the
    # result is a new custom design system, the chosen one with those values of the one in use now.
    # A request that asks for JSON gets the new style sheets, so the page repaints without a reload.
    def update
      return refuse_environment if @store.environment_id

      token_set = @store.find_set(params[:set_id].to_s)
      return refuse_unknown_set unless token_set

      kept = params[:compared].present? ? kept_values(token_set) : [{}, {}]
      token_set = kept.any?(&:any?) ? keep_values(token_set, *kept) : @store.activate(token_set.id)
      return refuse_too_many unless token_set

      OpenProject::Thematiq::Trial.stop(session)
      record_change("apply", token_set.name)
      notice = t("thematiq.admin.notice_applied", name: token_set.name)
      respond_to do |format|
        format.html do
          flash[:notice] = notice
          redirect_to action: :show
        end
        format.json { render json: { notice:, name: token_set.name, styles: helpers.thematiq_style_map(token_set) } }
      end
    end

    # --- a trial in your own session ---

    def trial
      token_set = @store.find_set(params[:set_id].to_s)
      return refuse_unknown_set unless token_set

      OpenProject::Thematiq::Trial.start(session, token_set.id)
      flash[:notice] = t("thematiq.trial.notice_started", name: token_set.name)
      redirect_to home_path
    end

    def trial_publish
      return refuse_environment if @store.environment_id

      token_set = @store.find_set(OpenProject::Thematiq::Trial.id(session).to_s)
      OpenProject::Thematiq::Trial.stop(session)
      return refuse_unknown_set unless token_set && @store.activate(token_set.id)

      record_change("trial_publish", token_set.name)
      flash[:notice] = t("thematiq.trial.notice_published", name: token_set.name)
      redirect_back_or_to admin_thematiq_path
    end

    def trial_discard
      OpenProject::Thematiq::Trial.stop(session)
      flash[:notice] = t("thematiq.trial.notice_discarded")
      redirect_back_or_to admin_thematiq_path
    end

    # The editor: the custom set, or a new one that starts from a design system of the catalogue.
    # id names a stored custom design system to edit. from names a design system to start a new one from.
    def edit
      start = @store.catalogue.find(params[:from].to_s)
      @draft = start ? nil : @store.custom_draft(params[:id].to_s)
      # A new one needs a free id. At the limit there is none, and the editor must not open on an id that is taken.
      return refuse_new_custom unless @draft || @store.next_custom_id

      @draft ||= new_draft(start || @store.catalogue.find(@store.active_id) || @store.catalogue.default)
      @stored = !@store.custom_draft(@draft.id).nil?
    end

    # "Start from your colours": a name and two colours give a draft that opens in the editor, unsaved.
    def from_colours
      overrides = OpenProject::Thematiq::ShortForm.derive(primary: params[:primary], background: params[:background])
      unless overrides && @store.next_custom_id
        flash[:error] = t(overrides ? "thematiq.transfer.errors.too_many" : "thematiq.short_form.error_colours")
        return redirect_to action: :show, anchor: "thematiq-short-form"
      end

      @draft = OpenProject::Thematiq::CustomDraft.new(base: @store.catalogue.default, name: params[:name].to_s.first(80), overrides:,
                                                      id: @store.next_custom_id)
      @stored = false
      flash.now[:notice] = t("thematiq.short_form.notice_drafted")
      render :edit
    end

    # One form posts here with several named buttons. Rails binds a CSRF token to one form action,
    # so preview, reset and delete are buttons on the same action and not URLs of their own.
    def update_custom
      id = custom_id_from_params
      return refuse_new_custom unless id

      if params[:delete].present?
        # A delete is asked once more, on a page of its own: it takes the uploaded files with it.
        return confirm_delete(id) if params[:confirmed].blank?

        deleted = id
        @store.delete_custom(deleted)
        # Its uploaded files go with it. The id is given out again, and the next owner must not inherit them.
        Thematiq::Upload.remove_set(deleted)
        # So do the choices that named it: those projects and modules inherit again.
        Thematiq::Scope.where(design_system_id: deleted).delete_all if Thematiq::Scope.ready?
        record_change("delete_custom", deleted)
        flash[:notice] = t("thematiq.editor.notice_deleted")
        return redirect_to action: :show
      end

      @draft = draft_from_params
      @stored = !@store.custom_draft(@draft.id).nil?
      if params[:preview].present? || params[:reset].present? || params[:reset_group].present? || params[:reset_all].present?
        flash.now[:notice] = t("thematiq.editor.notice_not_saved")
        render :edit
      elsif save_draft(@draft, new: !@stored)
        @store.activate(@draft.id)
        record_change("save_custom", @draft.name)
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
        record_change("shell")
        flash[:notice] = t(@store.nextcloud_url ? "thematiq.shell.settings.notice_saved" : "thematiq.shell.settings.notice_cleared")
      else
        flash[:error] = t("thematiq.shell.settings.error_invalid")
      end
      redirect_to action: :show
    end

    # The row of tiles in the top bar: the design's row, an own row in the order of the places, or none.
    def update_top_bar
      keys = Array(params[:tiles]).first(OpenProject::Thematiq::Shell::AppRow::MAX + 1)
      if @store.save_top_bar_apps(params[:top_bar_mode].to_s, keys)
        record_change("top_bar")
        flash[:notice] = t("thematiq.shell.top_bar.notice_saved")
      else
        flash[:error] = t("thematiq.shell.top_bar.error_invalid", max: OpenProject::Thematiq::Shell::AppRow::MAX)
      end
      redirect_to action: :show, anchor: "thematiq-top-bar"
    end

    # The icon pack: follow the design system, none, or one pack for every design system.
    def update_icon_pack
      if @store.save_icon_pack_choice(params[:icon_pack])
        record_change("icon_pack", @store.icon_pack_choice.presence)
        flash[:notice] = t("thematiq.icon_pack.notice_saved")
      else
        flash[:error] = t("thematiq.icon_pack.error_invalid")
      end
      redirect_to action: :show, anchor: "thematiq-icon-pack"
    end

    # The environment marker: a label on every page, such as "Test", in a colour. Empty clears it.
    def update_environment_marker
      if @store.save_environment_marker(params[:environment_label], params[:environment_colour])
        record_change("environment_marker", params[:environment_label].to_s.strip.first(30).presence)
        flash[:notice] = t("thematiq.marker.notice_saved")
      else
        flash[:error] = t("thematiq.marker.error_invalid")
      end
      redirect_to action: :show, anchor: "thematiq-marker"
    end

    # The administrator's own CSS. Checked part by part; one part that does not fit refuses all of it, with reasons.
    def update_custom_css
      result = @store.save_custom_css(enabled: params[:custom_css_enabled] == "1", text: params[:custom_css].to_s)
      if result.ok?
        record_change("custom_css")
        flash[:notice] = t(@store.custom_css_enabled? ? "thematiq.custom_css.notice_on" : "thematiq.custom_css.notice_off")
        redirect_to action: :show, anchor: "thematiq-custom-css"
      else
        @custom_css_text = params[:custom_css].to_s.first(OpenProject::Thematiq::CustomCss::MAX_BYTES)
        @custom_css_errors = result.errors
        flash.now[:error] = t("thematiq.custom_css.error")
        show
        render :show, status: :unprocessable_entity
      end
    end

    # A planned switch: a design system that becomes the one in use at a date and time, or the cancelling of one.
    # The time is read in the administrator's own time zone.
    def update_schedule
      if params[:cancel].present?
        @store.cancel_switch(params[:cancel].to_i)
        record_change("schedule", "cancelled")
        flash[:notice] = t("thematiq.schedule.notice_cancelled")
      else
        at = begin
          Time.zone.parse(params[:at].to_s)
        rescue ArgumentError
          nil
        end
        code = at ? @store.plan_switch(set_id: params[:set_id], at:) : "time"
        if code
          flash[:error] = t("thematiq.schedule.errors.#{code}")
        else
          record_change("schedule", "#{params[:set_id].to_s.first(64)} at #{at.utc.iso8601}")
          flash[:notice] = t("thematiq.schedule.notice_planned", name: @store.find_set(params[:set_id].to_s).name, time: helpers.format_time(at))
        end
      end
      redirect_to action: :show, anchor: "thematiq-schedule"
    end

    # E-mail in the house style, and the organisation's text under every e-mail.
    def update_email
      if @store.save_email_settings(styled: params[:email_styled] == "1", footer: params[:email_footer].to_s.first(OpenProject::Thematiq::Email::MAX_FOOTER + 1))
        record_change("email")
        flash[:notice] = t("thematiq.email.notice_saved")
      else
        flash[:error] = t("thematiq.email.error_invalid", count: OpenProject::Thematiq::Email::MAX_FOOTER)
      end
      redirect_to action: :show, anchor: "thematiq-email"
    end

    # The footer's legal links.
    def update_footer_links
      given = OpenProject::Thematiq::Store::FOOTER_LINKS.to_h { |kind| [kind, params.dig(:footer_links, kind).to_s] }
      if @store.save_footer_links(given)
        record_change("footer_links")
        flash[:notice] = t("thematiq.footer.notice_saved")
      else
        flash[:error] = t("thematiq.footer.error_invalid")
      end
      redirect_to action: :show, anchor: "thematiq-footer"
    end

    # An own token, --thematiq-org-<name>, or its removal.
    def update_own_token
      if params[:remove].present?
        @store.delete_own_token(params[:remove].to_s)
        record_change("own_token", params[:remove].to_s.first(40))
        flash[:notice] = t("thematiq.own_tokens.notice_removed")
      elsif (code = @store.save_own_token(name: params[:name], label: params[:label], kind: params[:kind], value: params[:value], dark: params[:dark]))
        flash[:error] = t("thematiq.own_tokens.errors.#{code}")
      else
        record_change("own_token", params[:name].to_s.first(40))
        flash[:notice] = t("thematiq.own_tokens.notice_saved", name: "--thematiq-org-#{params[:name].to_s.strip}")
      end
      redirect_to action: :show, anchor: "thematiq-own-tokens"
    end

    # A deprecation of one token, or its removal. It changes no value: it is a notice for the people who use the tokens.
    def update_deprecation
      if params[:remove].present?
        @store.delete_deprecation(params[:remove].to_s)
        record_change("deprecation", params[:remove].to_s.first(80))
        flash[:notice] = t("thematiq.deprecations.notice_removed")
      elsif (code = @store.save_deprecation(key: params[:key], severity: params[:severity], replacement: params[:replacement],
                                            removal: params[:removal], message: params[:message]))
        flash[:error] = t("thematiq.deprecations.errors.#{code}")
      else
        record_change("deprecation", params[:key].to_s.first(80))
        flash[:notice] = t("thematiq.deprecations.notice_saved")
      end
      redirect_to action: :show, anchor: "thematiq-deprecations"
    end

    # Design systems per project and module: whether projects may choose, from which, and one per module.
    def update_scopes
      return refuse_scopes("not_ready") unless Thematiq::Scope.ready?

      modules = OpenProject::Thematiq::Scopes::MODULES.keys.to_h { |name| [name, params.dig(:modules, name).to_s] }
      valid = modules.values.all? { |id| id.empty? || @store.find_set(id) }
      return refuse_scopes("invalid") unless valid && @store.save_project_rules(allow: params[:projects_may_choose] == "1",
                                                                                   choices: Array(params[:project_choices]))

      modules.each { |name, id| Thematiq::Scope.choose(project: nil, module_name: name, design_system_id: id.presence) }
      record_change("scopes")
      flash[:notice] = t("thematiq.scopes.admin.notice_saved")
      redirect_to action: :show, anchor: "thematiq-scopes"
    end

    # The uploaded files of a stored custom design system. One action with two named buttons per form:
    # "upload" stores the chosen file, and for a kind with one file that replaces it. "remove" carries the id
    # of the file to remove. Every upload is hostile input: the Inspector decides what it is by its content.
    def update_files
      id = params[:id].to_s
      library = id == OpenProject::Thematiq::Assets::LIBRARY_ID
      return render_404 unless library || @store.custom_draft(id)

      kind = OpenProject::Thematiq::Uploads.kind(params[:kind])
      # The library holds fonts only.
      raise OpenProject::Thematiq::Uploads::Refused, "unknown_kind" if library && params[:remove].blank? && kind&.name != "font"
      raise OpenProject::Thematiq::Uploads::Refused, "not_ready" unless Thematiq::Upload.ready?

      if params[:remove].present?
        return confirm_remove(id, params[:remove].to_s) if params[:confirmed].blank?

        removed = Thematiq::Upload.remove(set_id: id, token: params[:remove].to_s)
        raise OpenProject::Thematiq::Uploads::Refused, "not_stored" unless removed.positive?

        record_change("remove_upload", id)

        flash[:notice] = t("thematiq.uploads.notice_removed")
      else
        raise OpenProject::Thematiq::Uploads::Refused, "unknown_kind" unless kind

        stored = store_upload(id, kind)
        record_change("upload", "#{id}: #{kind.name}")
        flash[:notice] = t(stored.cleaned ? "thematiq.uploads.notice_stored_cleaned" : "thematiq.uploads.notice_stored",
                           kind: t("thematiq.uploads.kinds.#{kind.name}.label"))
      end
      redirect_after_files(id)
    rescue OpenProject::Thematiq::Uploads::Refused, ActiveRecord::RecordInvalid => e
      code = e.respond_to?(:code) ? e.code : "broken"
      flash[:error] = t("thematiq.uploads.errors.#{upload_error_key(code)}", **upload_limits(kind))
      redirect_after_files(id)
    end

    def redirect_after_files(id)
      return redirect_to action: :show, anchor: "thematiq-font-library" if id == OpenProject::Thematiq::Assets::LIBRARY_ID

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
                                                     overrides: imported.tokens, id: new_id, dark: imported.dark_tokens,
                                                     vocabulary: imported.vocabulary, dark_vocabulary: imported.dark_vocabulary,
                                                     logo: { "file" => imported.logo_file, "inverse_file" => imported.logo_inverse_file },
                                                     documentation_url: imported.documentation_url)
      raise OpenProject::Thematiq::Transfer::Refused, "token_invalid" unless save_draft(draft, new: true)

      record_change("import", draft.name)
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

    # The page with the Figma formats: the downloads of one design system, and the upload.
    def figma
      @token_set = @store.custom_set(params[:id].to_s) || @store.catalogue.find(params[:id].to_s)
    end

    # Sends one design system as a Figma token set, in the chosen format.
    def figma_download
      token_set = @store.custom_set(params[:id].to_s) || @store.catalogue.find(params[:id].to_s)
      format = OpenProject::Thematiq::Figma.format(params[:file_format])
      return render_404 unless token_set && format

      send_data OpenProject::Thematiq::Figma.export(token_set, format:),
                filename: OpenProject::Thematiq::Figma.file_name(token_set, format),
                type: "application/json", disposition: "attachment"
    end

    # Reads a CSS file of design tokens, the way thematiq writes a token set, as a new custom design system, and shows
    # what was read. Hostile input: CssTokens reads declarations only and checks every value. It never replaces one.
    def css_upload
      file = params[:file]
      text = file.respond_to?(:read) ? file.read(OpenProject::Thematiq::CssTokens::MAX_BYTES + 1).to_s : nil
      result = OpenProject::Thematiq::CssTokens.read(text)
      new_id = @store.next_custom_id
      raise OpenProject::Thematiq::CssTokens::Refused, "too_many_designs" unless new_id

      name = params[:name].to_s.strip.presence || t("thematiq.css_upload.default_name")
      @draft = OpenProject::Thematiq::CustomDraft.new(base: @store.catalogue.default, name: name.first(80), overrides: result.tokens, id: new_id,
                                                      dark: result.dark, vocabulary: result.vocabulary, dark_vocabulary: result.dark_vocabulary)
      raise OpenProject::Thematiq::CssTokens::Refused, "name" unless save_draft(@draft, new: true)

      record_change("import", @draft.name)
      @css_result = result
      render :css_report
    rescue OpenProject::Thematiq::CssTokens::Refused => e
      flash[:error] = t("thematiq.css_upload.errors.#{CSS_ERRORS.include?(e.code) ? e.code : 'not_css'}")
      redirect_to action: :show, anchor: "thematiq-css-upload"
    end

    # Converts an NL Design System theme by thematiq's table into a new custom design system, and shows the report.
    def nlds_upload
      file = params[:file]
      text = file.respond_to?(:read) ? file.read(OpenProject::Thematiq::CssTokens::MAX_BYTES + 1).to_s.force_encoding(Encoding::UTF_8) : nil
      result = OpenProject::Thematiq::NldsConverter.convert(text, prefix: params[:prefix].to_s.first(31))
      new_id = @store.next_custom_id
      raise OpenProject::Thematiq::CssTokens::Refused, "too_many_designs" unless new_id

      name = params[:name].to_s.strip.presence || t("thematiq.nlds.default_name")
      @draft = OpenProject::Thematiq::CustomDraft.new(base: @store.catalogue.default, name: name.first(80), overrides: result.tokens, id: new_id,
                                                      vocabulary: result.vocabulary)
      raise OpenProject::Thematiq::CssTokens::Refused, "name" unless save_draft(@draft, new: true)

      record_change("import", @draft.name)
      @nlds_result = result
      render :nlds_report
    rescue OpenProject::Thematiq::CssTokens::Refused => e
      flash[:error] = t("thematiq.nlds.errors.#{NLDS_ERRORS.include?(e.code) ? e.code : 'not_css'}")
      redirect_to action: :show, anchor: "thematiq-nlds-upload"
    end

    # Reads an uploaded Figma token set as a new custom design system and shows what was read.
    # The files are hostile input: Figma::Reader checks all of it. It never replaces a design system.
    def figma_upload
      result = OpenProject::Thematiq::Figma::Reader.read(figma_files)
      new_id = @store.next_custom_id
      raise figma_refused("too_many") unless new_id

      name = result.name || t("thematiq.figma.default_name")
      @draft = OpenProject::Thematiq::CustomDraft.new(base: @store.catalogue.default, name:, overrides: result.tokens, id: new_id, dark: result.dark,
                                                    vocabulary: result.vocabulary, dark_vocabulary: result.dark_vocabulary)
      raise figma_refused("nothing_usable") unless save_draft(@draft, new: true)

      record_change("figma_upload", @draft.name)
      @result = result
      render :figma_report
    rescue OpenProject::Thematiq::Figma::Reader::Refused => e
      flash[:error] = t("thematiq.figma.errors.#{figma_error_key(e.code)}")
      redirect_to action: :figma
    end

    # --- the history: every change with who made it, and the setup after it, to restore ---

    def history
      @changes = Thematiq::Change.ready? ? Thematiq::Change.order(id: :desc).limit(200).to_a : []
      @ready = Thematiq::Change.ready?
    end

    # What restoring one version changes, before anything is written. A version that no longer reads is refused whole.
    def history_version
      @change = find_change
      return render_404 unless @change

      @checked, @refusal = checked_version(@change)
      @changes_list = @checked ? OpenProject::Thematiq::Bundle.changes(Thematiq::Change.current_bundle(@store), @checked) : []
      @names = design_system_names(@checked)
    end

    def restore
      change = find_change
      return render_404 unless change

      checked, refusal = checked_version(change)
      if checked
        Thematiq::Change.apply!(checked, store: @store)
        record_change("restore", "##{change.id}")
        flash[:notice] = t("thematiq.history.notice_restored", time: helpers.format_time(change.created_at))
        redirect_to action: :history
      else
        flash[:error] = t("thematiq.bundle.errors.#{bundle_error_key(refusal)}")
        redirect_to action: :history_version, id: change.id
      end
    end

    # For a monitoring system or an administrator: does the plugin work, and what is wrong if not. Admins only.
    # 200 when all is well, 503 when something is degraded, so a probe needs nothing but the status.
    def health
      report = OpenProject::Thematiq::Health.report(store: @store, tables: table_states, core_changed: core_changes)
      render json: report, status: report["status"] == "ok" ? :ok : :service_unavailable
    end

    # The playground (app-component-playground): OpenProject's own Primer components in each state, in the content area,
    # drawn with a chosen design system. Only the content area changes; the top bar and the menu keep the one in use.
    def playground
      @playground_set = @store.find_set(params[:set_id].to_s) || @store.active_token_set
      active = @store.active_token_set
      thematiq = OpenProject::Thematiq
      source = thematiq::Scopes::Source.new(kind: :module)
      RequestStore.store[:thematiq_page_scope] = thematiq::PageScope::Result.new(
        page_set: active, content_set: @playground_set, module_name: nil,
        resolution: thematiq::Scopes::Resolution.new(page: [nil, thematiq::Scopes::INSTANCE],
                                                    content: [@playground_set.id == active.id ? nil : @playground_set.id, source])
      )
    end

    # Your own component in a design system (aut-component-preview): HTML and CSS you paste, drawn in a sandboxed frame
    # with the design system's style sheet. Nothing is stored. The frame runs no script and has an origin of its own;
    # the CSS goes through CustomCss first, so a url() or an import cannot fetch anything.
    def component_preview
      @playground_set = @store.find_set(params[:set_id].to_s) || @store.active_token_set
      @preview_html = params[:html].to_s.first(20_000)
      css = OpenProject::Thematiq::CustomCss.check(params[:css].to_s)
      @preview_css_errors = css.errors
      root = OpenProject::Configuration["rails_relative_url_root"].to_s
      own = css.ok? ? css.css : ""
      sheet = [OpenProject::Thematiq::Stylesheet.css(@playground_set), OpenProject::Thematiq::Assets.bundled.font_face_css(@playground_set, root:), own].join("\n")
      @srcdoc = "<!doctype html><html><head><meta charset=\"utf-8\"><style>#{sheet.gsub(%r{</style}i, '')}</style></head>" \
                "<body data-color-mode=\"light\" data-light-theme=\"light\" style=\"padding: 16px\">#{@preview_html}</body></html>"
      playground
      render :playground
    end

    # A design system per group, in priority order: the rows of the form, top first.
    def update_groups
      rows = Array(params[:groups]).first(OpenProject::Thematiq::Store::MAX_GROUP_CHOICES + 1).map do |row|
        row.respond_to?(:permit) ? row.permit(:group_id, :design_system_id).to_h.values_at("group_id", "design_system_id") : []
      end
      if @store.save_group_choices(rows)
        record_change("groups")
        flash[:notice] = t("thematiq.groups.notice_saved")
      else
        flash[:error] = t("thematiq.groups.error_invalid")
      end
      redirect_to action: :show, anchor: "thematiq-groups"
    end

    # The shared light or dark choice: whether another product may link a person here to set it.
    def update_appearance
      @store.save_appearance_link(params[:appearance_link_enabled] == "1")
      record_change("appearance")
      flash[:notice] = t("thematiq.appearance.notice_saved")
      redirect_to action: :show, anchor: "thematiq-appearance"
    end

    # --- the gallery: thematiq's design systems from one https address, when an administrator turned it on ---

    def gallery; end

    # One form, several buttons: save the switch and the address, check now, add one set, dismiss the notice.
    def update_gallery
      if params[:save].present?
        if @store.save_gallery_settings(enabled: params[:gallery_enabled] == "1", url: params[:gallery_url])
          record_change("gallery")
          flash[:notice] = t("thematiq.gallery.notice_saved")
        else
          flash[:error] = t("thematiq.gallery.errors.url")
        end
      elsif params[:dismiss].present?
        @store.dismiss_gallery_notice
        return redirect_to action: :show
      elsif params[:add].present?
        return add_from_gallery(params[:add].to_s)
      elsif params[:check].present?
        @gallery_sets = check_gallery
        return render :gallery
      end
      redirect_to action: :gallery
    end

    # Evidence of contrast for an audit: every design system in use, light and dark. HTML to read or print, JSON to keep.
    def compliance
      @report = OpenProject::Thematiq::Compliance.report(design_systems_in_use, generated_at: Time.current.utc.iso8601)
      respond_to do |format|
        format.html
        format.json do
          send_data JSON.pretty_generate(@report), filename: "openproject-thematiq-contrast-#{Time.current.strftime('%Y-%m-%d')}.json",
                                                   type: "application/json", disposition: "attachment"
        end
      end
    end

    # The history as a CSV file, for an auditor. Every row, newest first; the setup itself stays in OpenProject.
    def history_export
      rows = Thematiq::Change.ready? ? Thematiq::Change.order(id: :desc).to_a : []
      send_data history_csv(rows), filename: "openproject-thematiq-history-#{Time.current.strftime('%Y-%m-%d')}.csv",
                                   type: "text/csv", disposition: "attachment"
    end

    # --- the configuration file: the whole setup, to move from test to production ---

    def bundle_export
      send_data OpenProject::Thematiq::Bundle.dump(Thematiq::Change.current_bundle(@store)),
                filename: "openproject-thematiq-setup-#{Time.current.strftime('%Y-%m-%d')}.json",
                type: "application/json", disposition: "attachment"
    end

    # Reads a configuration file and shows what it changes. Nothing is written: the file goes back in the form of
    # the page, and is read and checked again when the administrator confirms.
    def bundle_import
      file = params[:file]
      @bundle_text = file.respond_to?(:read) ? file.read(OpenProject::Thematiq::Bundle::MAX_BYTES + 1).to_s : params[:bundle].to_s
      checked = read_bundle(@bundle_text)
      if params[:confirmed].present?
        Thematiq::Change.apply!(checked, store: @store)
        record_change("bundle_import")
        flash[:notice] = t("thematiq.bundle.notice_applied")
        return redirect_to action: :show
      end

      @changes_list = OpenProject::Thematiq::Bundle.changes(Thematiq::Change.current_bundle(@store), checked)
      @names = design_system_names(checked)
    rescue OpenProject::Thematiq::Bundle::Refused => e
      flash[:error] = t("thematiq.bundle.errors.#{bundle_error_key(e.code)}")
      redirect_to action: :show, anchor: "thematiq-bundle"
    end

    private

    # [[token set, where]] for the instance, every project and every module with a design system of its own.
    def design_systems_in_use
      list = [[@store.active_token_set, "instance"]]
      return list unless Thematiq::Scope.ready?

      names = Project.where(id: Thematiq::Scope.where.not(project_id: nil).select(:project_id)).pluck(:id, :identifier).to_h
      Thematiq::Scope.find_each do |row|
        token_set = @store.find_set(row.design_system_id)
        next unless token_set

        place = row.project_id ? "project #{names[row.project_id]}" : "instance"
        list << [token_set, row.module_name.blank? ? place : "#{place}, module #{row.module_name}"]
      end
      list
    end

    def table_states
      { "uploads" => Thematiq::Upload.ready?, "scopes" => Thematiq::Scope.ready?, "changes" => Thematiq::Change.ready? }
    end

    def core_changes
      OpenProject::Thematiq::Shell::CoreGuard.changed_files
    rescue StandardError
      ["unknown"]
    end

    # The environment names the design system: the page cannot change it.
    def refuse_environment
      flash[:error] = t("thematiq.environment.error_apply", variable: OpenProject::Thematiq::Store::ENVIRONMENT_KEY)
      redirect_to action: :show
    end

    def read_bundle(text)
      OpenProject::Thematiq::Bundle.read(text.to_s.force_encoding(Encoding::UTF_8), catalogue: @store.catalogue,
                                                                                    project_exists: ->(identifier) { Project.exists?(identifier:) })
    end

    def history_csv(rows)
      require "csv"
      CSV.generate do |csv|
        csv << %w[time user action detail restorable]
        rows.each do |row|
          # A cell that starts like a formula is quoted, so a spreadsheet does not run it.
          safe = ->(text) { text.to_s.match?(/\A[=+\-@\t\r]/) ? "'#{text}" : text.to_s }
          csv << [row.created_at.utc.iso8601, safe.call(row.user_name), row.action, safe.call(row.detail), row.restorable?]
        end
      end
    end

    # Fetches the gallery, keeps what it found, and returns the sets that are new or changed. [] when it failed.
    def check_gallery
      gallery = OpenProject::Thematiq::Gallery.read(OpenProject::Thematiq::Gallery::Client.fetch(@store.gallery_url, enabled: @store.gallery_enabled?))
      fresh = OpenProject::Thematiq::Gallery.new_or_changed(gallery, @store.catalogue)
      @store.record_gallery_status("checked_at" => Time.now.to_i, "generated_from" => gallery.generated_from, "sets" => gallery.sets.size,
                                   "new" => fresh.size, "error" => nil)
      fresh
    rescue OpenProject::Thematiq::Gallery::Off
      []
    rescue OpenProject::Thematiq::Gallery::Refused => e
      @store.record_gallery_status("checked_at" => Time.now.to_i, "error" => e.code.to_s.first(60))
      []
    end

    # One set of the gallery as a new custom design system, read and checked like an imported file.
    def add_from_gallery(id)
      token_set = check_gallery.find { |candidate| candidate.id == id }
      new_id = @store.next_custom_id
      if token_set && new_id
        draft = OpenProject::Thematiq::CustomDraft.new(base: @store.catalogue.default, name: token_set.name.first(80), overrides: token_set.tokens, id: new_id,
                                                       dark: token_set.dark_tokens, vocabulary: token_set.vocabulary,
                                                       dark_vocabulary: token_set.dark_vocabulary, documentation_url: token_set.documentation_url)
        if save_draft(draft, new: true)
          record_change("import", draft.name)
          flash[:notice] = t("thematiq.gallery.notice_added", name: draft.name)
          return redirect_to action: :show
        end
      end
      flash[:error] = t(new_id ? "thematiq.gallery.errors.add" : "thematiq.transfer.errors.too_many")
      redirect_to action: :gallery
    end

    # The id of the design system in use: a custom one, else the catalogue's.
    def current_id
      @store.active_custom_id || @store.active_token_set.id
    end

    def refuse_unknown_set
      flash[:error] = t("thematiq.admin.error_unknown_set")
      redirect_to action: :show
    end

    def refuse_too_many
      flash[:error] = t("thematiq.transfer.errors.too_many")
      redirect_to action: :show
    end

    def kept_values(token_set)
      rows = OpenProject::Thematiq::Diff.between(@store.active_token_set, token_set)
      OpenProject::Thematiq::Diff.kept(rows, params[:take])
    end

    # The chosen design system with some values of the one in use: stored as a new custom design system and applied.
    def keep_values(token_set, light, dark)
      chosen = @store.custom_draft(token_set.id)
      base = chosen ? chosen.base : token_set
      overrides = chosen ? chosen.overrides.merge(chosen.vocabulary) : {}
      roles = dark.select { |key, _| OpenProject::Thematiq::Tokens::TokenSet::DARK_KEYS.include?(key) }
      new_id = @store.next_custom_id
      return nil unless new_id

      draft = OpenProject::Thematiq::CustomDraft.new(base:, name: t("thematiq.compare.kept_name", name: token_set.name).first(80),
                                                     overrides: overrides.merge(light), id: new_id,
                                                     dark: (chosen ? chosen.dark : {}).merge(roles),
                                                     dark_vocabulary: (chosen ? chosen.dark_vocabulary : {}).merge(dark.except(*roles.keys)),
                                                     documentation_url: chosen&.documentation_url)
      return nil unless save_draft(draft, new: true)

      @store.activate(new_id)
    end

    BUNDLE_ERRORS = %w[empty too_large invalid_json not_a_bundle version unknown_keys settings customs custom_invalid active projects
                       nextcloud_url top_bar_apps scopes scope_design_system scope_project cleared environment_marker
                       deprecations custom_css own_tokens locks planned_switches footer_links email gallery appearance groups icon_pack].freeze

    def bundle_error_key(code)
      BUNDLE_ERRORS.include?(code) ? code : "invalid_json"
    end

    def find_change
      Thematiq::Change.ready? ? Thematiq::Change.find_by(id: params[:id].to_i) : nil
    end

    # [checked bundle, nil] or [nil, refusal code].
    def checked_version(change)
      document = change.bundle_document
      return [nil, "cleared"] unless document

      [OpenProject::Thematiq::Bundle.read(document, catalogue: @store.catalogue,
                                                     project_exists: ->(identifier) { Project.exists?(identifier:) }), nil]
    rescue OpenProject::Thematiq::Bundle::Refused => e
      [nil, e.code]
    end

    # Design system id to name, from what is here now and from the version.
    def design_system_names(checked)
      names = @store.all_sets.to_h { |token_set| [token_set.id, token_set.name] }
      (checked&.settings&.dig("customs") || {}).each { |id, definition| names[id] ||= definition["name"].to_s }
      names
    end

    # One row of the history. Never fails the action that called it.
    def record_change(action, detail = nil)
      Thematiq::Change.record(action, detail:, store: @store)
    end

    CSS_ERRORS = %w[empty too_large not_css too_many nothing_usable too_many_designs name].freeze
    NLDS_ERRORS = %w[empty too_large not_css too_many too_deep nothing_usable too_many_designs name prefix].freeze
    FIGMA_ERRORS = %w[empty too_large too_many_files invalid_json not_an_object too_deep too_many_tokens nothing_usable too_many].freeze

    def figma_refused(code)
      OpenProject::Thematiq::Figma::Reader::Refused.new(code)
    end

    def figma_error_key(code)
      FIGMA_ERRORS.include?(code) ? code : "invalid_json"
    end

    # The chosen files as [name, text]. Reading stops one byte over the cap for all files together, so a huge
    # upload is refused without being loaded. The name the browser sent only names a token set of a folder upload.
    def figma_files
      reader = OpenProject::Thematiq::Figma::Reader
      left = reader::MAX_BYTES + 1
      Array(params[:files]).select { |file| file.respond_to?(:read) }.first(reader::MAX_FILES + 1).map do |file|
        text = left.positive? ? file.read(left).to_s : ""
        left -= text.bytesize
        [file.respond_to?(:original_filename) ? File.basename(file.original_filename.to_s) : "", text]
      end
    end

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
      # The French State's Marianne typeface is reserved for its administrations (typ-marianne-gated): the uploader
      # confirms the entitlement first.
      if face && OpenProject::Thematiq::Uploads::FontFace.gated?(face.family) && params[:marianne_entitled] != "1"
        raise OpenProject::Thematiq::Uploads::Refused, "font_not_entitled"
      end
      result = OpenProject::Thematiq::Uploads::Inspector.inspect_upload(kind.name, bytes)
      Thematiq::Upload.store!(set_id:, result:, face:, label: file.respond_to?(:original_filename) ? file.original_filename.to_s : nil)
      result
    end

    UPLOAD_ERRORS = %w[empty too_large unknown_type wrong_type broken too_small too_wide svg_declares svg_not_svg svg_too_complex
                       font_family_invalid font_weight_invalid font_style_invalid too_many_fonts not_stored not_ready unknown_kind
                       font_not_entitled interlaced].freeze

    def upload_error_key(code)
      UPLOAD_ERRORS.include?(code) ? code : "broken"
    end

    # The numbers an error message may name.
    def upload_limits(kind)
      return {} unless kind

      { types: kind.formats.map { |format| OpenProject::Thematiq::Uploads::FORMATS.fetch(format)[:label] }.join(", "),
        size: OpenProject::Thematiq::Uploads.human_size(kind.max_bytes), min: kind.min_side, width: kind.max_width, height: kind.max_height,
        count: OpenProject::Thematiq::Uploads::MAX_FONTS }
    end

    def import_error_key(code)
      %w[empty too_large invalid_json unknown_keys token_invalid name_invalid documentation_url_invalid too_many].include?(code) ? code : "not_a_set"
    end

    def new_draft(base)
      OpenProject::Thematiq::CustomDraft.new(base:, name: t("thematiq.editor.default_name", name: base.name).first(80), overrides: {},
                                             id: @store.next_custom_id)
    end

    # The id of a stored custom design system, or the id a new one gets. Never an id from outside as it is.
    # nil when the form names no stored one and all ids are taken: falling back to a taken id would overwrite it.
    def custom_id_from_params
      id = params[:id].to_s
      @store.custom_draft(id) ? id : @store.next_custom_id
    end

    # The question before a delete: a page of its own with a form, so it works without scripts and by keyboard.
    def confirm_delete(id)
      draft = @store.custom_draft(id)
      return render_404 unless draft

      @confirm = { title: t("thematiq.editor.confirm_delete.title"),
                   question: t("thematiq.editor.confirm_delete.question", name: draft.name),
                   consequence: t("thematiq.editor.confirm_delete.consequence"),
                   button: t("thematiq.editor.confirm_delete.confirm"),
                   url: admin_thematiq_custom_path, fields: { id:, delete: "1" },
                   back: admin_thematiq_custom_path(id:) }
      render :confirm
    end

    # The question before an uploaded file is removed. Only a file of this design system can be asked about.
    def confirm_remove(id, token)
      record = Thematiq::Upload.find_record(token)
      raise OpenProject::Thematiq::Uploads::Refused, "not_stored" unless record && record.set_id == id

      @confirm = { title: t("thematiq.uploads.confirm_remove.title"),
                   question: t("thematiq.uploads.confirm_remove.question", file: upload_description(record),
                                                                           name: id == OpenProject::Thematiq::Assets::LIBRARY_ID ? t("thematiq.library.title") : @store.custom_draft(id).name),
                   consequence: t("thematiq.uploads.confirm_remove.consequence"),
                   button: t("thematiq.uploads.confirm_remove.confirm"),
                   url: admin_thematiq_custom_files_path, fields: { id:, remove: token },
                   back: id == OpenProject::Thematiq::Assets::LIBRARY_ID ? admin_thematiq_path(anchor: "thematiq-font-library") : admin_thematiq_custom_path(id:) }
      render :confirm
    end

    def upload_description(record)
      return t("thematiq.uploads.kinds.#{record.kind}.label") unless record.face

      t("thematiq.uploads.confirm_remove.font", family: record.face.family,
                                                weight: t("thematiq.uploads.weights.w#{record.face.weight.tr(' ', '_')}"),
                                                style: t("thematiq.uploads.styles.#{record.face.style}"))
    end

    def refuse_scopes(code)
      flash[:error] = t("thematiq.scopes.admin.error_#{code}")
      redirect_to action: :show, anchor: "thematiq-scopes"
    end

    def refuse_new_custom
      flash[:error] = t("thematiq.transfer.errors.too_many")
      redirect_to action: :show
    end

    def draft_from_params
      base = @store.catalogue.find(params[:based_on].to_s) || @store.catalogue.default
      typed = params[:tokens].respond_to?(:permit) ? params[:tokens].permit(*token_keys).to_h : {}
      typed = {} if params[:reset_all].present?
      typed = typed.except(params[:reset].to_s) if params[:reset].present?
      typed = typed.except(*OpenProject::Thematiq::Editor.keys_of(params[:reset_group])) if params[:reset_group].present?
      dark = dark_from_params
      id = custom_id_from_params
      stored = @store.custom_draft(id)
      OpenProject::Thematiq::CustomDraft.new(base:, name: params[:name].to_s, overrides: typed, id:,
                                             logo: stored&.definition&.dig("logo"),
                                             dark:, dark_errors: true,
                                             # The editor has dark fields for colours only. Other dark values an import brought stay.
                                             dark_vocabulary: kept_dark_vocabulary(stored).merge(dark),
                                             lock_primary: params[:lock_primary] == "1",
                                             documentation_url: params[:documentation_url].to_s.first(600))
    end

    # The dark fields: one per colour, roles and vocabulary in one list. Reset clears the dark value with the light one.
    def dark_from_params
      keys = OpenProject::Thematiq::Editor::DARK_FIELDS
      dark = params[:dark].respond_to?(:permit) ? params[:dark].permit(*keys).to_h : {}
      dark = {} if params[:reset_all].present?
      dark = dark.except(params[:reset].to_s) if params[:reset].present?
      dark = dark.except(*OpenProject::Thematiq::Editor.keys_of(params[:reset_group])) if params[:reset_group].present?
      dark
    end

    def kept_dark_vocabulary(stored)
      return {} unless stored && params[:reset_all].blank?

      stored.dark_vocabulary.except(*OpenProject::Thematiq::Editor::DARK_FIELDS)
    end

    def token_keys
      # Every role, the optional ones as well, and every key of the vocabulary: the form has a field for each.
      # The two sets of names never overlap, so one list of fields holds both and the draft sorts them.
      OpenProject::Thematiq::Editor::KINDS.keys
    end

    def load_state
      @store = OpenProject::Thematiq::Store.new
      # An installation that ran the first version still holds a thematiq address and a fetched token set.
      # They are removed the first time an administrator opens this page.
      @store.remove_legacy_settings
    end
  end
end
