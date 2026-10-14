# frozen_string_literal: true

Rails.application.routes.draw do
  get "admin/thematiq", to: "thematiq/admin#show", as: :admin_thematiq
  post "admin/thematiq", to: "thematiq/admin#update"
  get "admin/thematiq/custom", to: "thematiq/admin#edit", as: :admin_thematiq_custom
  post "admin/thematiq/custom", to: "thematiq/admin#update_custom"
  post "admin/thematiq/custom/files", to: "thematiq/admin#update_files", as: :admin_thematiq_custom_files
  get "admin/thematiq/export", to: "thematiq/admin#export", as: :admin_thematiq_export
  post "admin/thematiq/import", to: "thematiq/admin#import", as: :admin_thematiq_import
  get "admin/thematiq/figma", to: "thematiq/admin#figma", as: :admin_thematiq_figma
  get "admin/thematiq/figma/download", to: "thematiq/admin#figma_download", as: :admin_thematiq_figma_download
  post "admin/thematiq/figma", to: "thematiq/admin#figma_upload"
  post "admin/thematiq/shell", to: "thematiq/admin#update_shell", as: :admin_thematiq_shell
  post "admin/thematiq/top-bar", to: "thematiq/admin#update_top_bar", as: :admin_thematiq_top_bar
  post "admin/thematiq/scopes", to: "thematiq/admin#update_scopes", as: :admin_thematiq_scopes
  get "admin/thematiq/history", to: "thematiq/admin#history", as: :admin_thematiq_history
  get "admin/thematiq/history/:id", to: "thematiq/admin#history_version", as: :admin_thematiq_history_version, constraints: { id: /\d{1,12}/ }
  post "admin/thematiq/history/:id", to: "thematiq/admin#restore", constraints: { id: /\d{1,12}/ }

  # The design system of one project and of its modules. For a project admin with "Choose design system".
  get "projects/:project_id/settings/design", to: "thematiq/project_design#show", as: :project_settings_thematiq_design
  post "projects/:project_id/settings/design", to: "thematiq/project_design#update"

  # The uploaded files of the design systems. Public, and only for an id of 64 hex characters.
  get "thematiq/files/:token", to: "thematiq/files#show", constraints: { token: /[0-9a-f]{64}/ }, format: false,
                               as: :thematiq_file
end
