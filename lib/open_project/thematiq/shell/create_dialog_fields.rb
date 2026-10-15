# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Shell
      # The fields of the OpCreateWorkPackage board that core's create dialog leaves out: Parent, Assignee, Priority,
      # Start date and Due date, and, when a Nextcloud address is set, "Link the project folder in Nextcloud".
      #
      # Core's form, WorkPackages::Dialogs::CreateForm, renders the type, the subject, the description and the
      # required custom fields, then a hidden field for every other attribute the work package already has. The
      # plugin prepends two methods to it:
      #
      #   render_custom_fields   adds the board's fields with core's own form inputs (the work package and user
      #                          autocompleters, a select list, date fields), each only when core's create contract
      #                          lets this user write that attribute; then calls core's method.
      #   writable_attributes    leaves the attributes it rendered out of core's hidden fields, so the visible field
      #                          is the one that is sent.
      #
      # The values go in work_package[...] like core's own fields, so core's controller permits them, CreateService
      # sets and validates them, and errors show in the dialog. On a change of type core redraws the form with what
      # was filled in.
      #
      # Written against app/forms/work_packages/dialogs/create_form.rb of OpenProject 17.9.1, which CoreGuard checks
      # in the part create_dialog. When it differs, this is not installed and core's form renders as it is.
      module CreateDialogFields
        # Board field => the work package attribute it writes.
        ATTRIBUTES = {
          parent: "parent_id",
          assignee: "assigned_to_id",
          priority: "priority_id",
          start_date: "start_date",
          due_date: "due_date"
        }.freeze

        def self.install!
          form = ::WorkPackages::Dialogs::CreateForm
          form.prepend(FormFields) unless form.ancestors.include?(FormFields)
          @installed = true
        end

        def self.installed?
          @installed == true
        end

        # The attributes the dialog renders for a contract that lets the user write `writable`.
        def self.rendered(writable)
          ATTRIBUTES.values.select { |attribute| writable.include?(attribute) }
        end

        # Both names an attribute goes by in core's lists: with and without "_id".
        def self.names(attributes)
          attributes.flat_map { |attribute| [attribute, attribute.delete_suffix("_id")] }.uniq
        end

        module FormFields
          def render_custom_fields(form:)
            begin
              thematiq_board_fields(form)
            rescue StandardError => e
              @thematiq_rendered = []
              Rails.logger.error("[openproject-thematiq] The board's fields of the create dialog are off: #{e.class}: #{e.message}")
            end
            super
          end

          private

          def writable_attributes
            rendered = Array(@thematiq_rendered)
            return super if rendered.empty?

            super - CreateDialogFields.names(rendered)
          end

          def thematiq_board_fields(form)
            rendered = CreateDialogFields.rendered(contract.writable_attributes)
            @thematiq_rendered = []
            rendered.each do |attribute|
              send(:"thematiq_#{attribute}_field", form)
              @thematiq_rendered << attribute
            end
            thematiq_nextcloud_note(form)
          end

          def thematiq_parent_id_field(form)
            form.work_package_autocompleter(
              name: :parent_id,
              label: ::WorkPackage.human_attribute_name(:parent),
              wrapper_data_attributes: { "thematiq-field": "parent" },
              autocomplete_options: {
                focusDirectly: false,
                openDirectly: false,
                appendTo: wrapper_id,
                inputValue: work_package.parent_id,
                data: { "test-selector": "thematiq-create-parent" }
              }
            )
          end

          def thematiq_assigned_to_id_field(form)
            form.autocompleter(
              name: :assigned_to_id,
              label: ::WorkPackage.human_attribute_name(:assigned_to),
              wrapper_data_attributes: { "thematiq-field": "assignee" },
              autocomplete_options: {
                component: "opce-user-autocompleter",
                defaultData: false,
                placeholder: I18n.t(:label_user_search),
                resource: "principals",
                url: ::API::V3::Utilities::PathHelper::ApiV3Path.principals,
                searchKey: "any_name_attribute",
                filters: [
                  { name: "type", operator: "=", values: %w[User Group PlaceholderUser] },
                  { name: "status", operator: "!", values: [::Principal.statuses["locked"].to_s] },
                  { name: "member", operator: "=", values: [work_package.project_id.to_s] }
                ],
                inputValue: work_package.assigned_to_id,
                focusDirectly: false,
                appendTo: wrapper_id,
                data: { "test-selector": "thematiq-create-assignee" }
              }
            )
          end

          def thematiq_priority_id_field(form)
            form.select_list(
              name: :priority_id,
              label: ::WorkPackage.human_attribute_name(:priority),
              data: { "thematiq-field": "priority" }
            ) do |list|
              ::IssuePriority.active.each do |priority|
                list.option(label: priority.name, value: priority.id, selected: work_package.priority_id == priority.id)
              end
            end
          end

          def thematiq_start_date_field(form)
            form.text_field(name: :start_date, type: "date", label: ::WorkPackage.human_attribute_name(:start_date),
                            data: { "thematiq-field": "start-date" })
          end

          def thematiq_due_date_field(form)
            form.text_field(name: :due_date, type: "date", label: ::WorkPackage.human_attribute_name(:due_date),
                            data: { "thematiq-field": "due-date" })
          end

          # Nothing in the plugin can link a folder: OpenProject's Nextcloud integration links project folders
          # through a file storage, set up per project by an administrator. So the board's checkbox shows, when a
          # Nextcloud address is set, as a disabled box with a note that says so. It has no name: nothing is sent.
          def thematiq_nextcloud_note(form)
            return if Shell.nextcloud_url.nil?

            label = I18n.t("thematiq.shell.create_dialog.nextcloud_folder")
            note = I18n.t("thematiq.shell.create_dialog.nextcloud_folder_note")
            form.html_content do
              content_tag(:div, class: "thematiq-create__nextcloud", data: { "thematiq-field": "nextcloud" }) do
                safe_join([
                  content_tag(:label, class: "thematiq-create__check") do
                    safe_join([tag.input(type: "checkbox", disabled: true, "aria-describedby": "thematiq-create-nextcloud-note"), label])
                  end,
                  content_tag(:p, note, id: "thematiq-create-nextcloud-note", class: "thematiq-create__note")
                ])
              end
            end
          end
        end
      end
    end
  end
end
