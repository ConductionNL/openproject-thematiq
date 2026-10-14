# frozen_string_literal: true

Rails.application.routes.draw do
  get "admin/thematiq", to: "thematiq/admin#show", as: :admin_thematiq
  post "admin/thematiq", to: "thematiq/admin#update"
  get "admin/thematiq/compare", to: "thematiq/admin#compare", as: :admin_thematiq_compare
  post "admin/thematiq/trial", to: "thematiq/admin#trial", as: :admin_thematiq_trial
  post "admin/thematiq/trial/publish", to: "thematiq/admin#trial_publish", as: :admin_thematiq_trial_publish
  post "admin/thematiq/trial/discard", to: "thematiq/admin#trial_discard", as: :admin_thematiq_trial_discard
  get "admin/thematiq/custom", to: "thematiq/admin#edit", as: :admin_thematiq_custom
  post "admin/thematiq/custom", to: "thematiq/admin#update_custom"
  post "admin/thematiq/from-colours", to: "thematiq/admin#from_colours", as: :admin_thematiq_from_colours
  post "admin/thematiq/custom/files", to: "thematiq/admin#update_files", as: :admin_thematiq_custom_files
  get "admin/thematiq/export", to: "thematiq/admin#export", as: :admin_thematiq_export
  post "admin/thematiq/import", to: "thematiq/admin#import", as: :admin_thematiq_import
  post "admin/thematiq/css", to: "thematiq/admin#css_upload", as: :admin_thematiq_css
  post "admin/thematiq/nlds", to: "thematiq/admin#nlds_upload", as: :admin_thematiq_nlds
  get "admin/thematiq/figma", to: "thematiq/admin#figma", as: :admin_thematiq_figma
  get "admin/thematiq/figma/download", to: "thematiq/admin#figma_download", as: :admin_thematiq_figma_download
  post "admin/thematiq/figma", to: "thematiq/admin#figma_upload"
  post "admin/thematiq/shell", to: "thematiq/admin#update_shell", as: :admin_thematiq_shell
  post "admin/thematiq/top-bar", to: "thematiq/admin#update_top_bar", as: :admin_thematiq_top_bar
  post "admin/thematiq/custom-css", to: "thematiq/admin#update_custom_css", as: :admin_thematiq_custom_css
  post "admin/thematiq/own-tokens", to: "thematiq/admin#update_own_token", as: :admin_thematiq_own_tokens
  get "thematiq/api/v1/icons", to: "thematiq/api#icons", as: :thematiq_api_icons, format: false
  get "thematiq/api/v1/own-tokens", to: "thematiq/api#own_tokens", as: :thematiq_api_own_tokens, format: false
  post "admin/thematiq/schedule", to: "thematiq/admin#update_schedule", as: :admin_thematiq_schedule
  post "admin/thematiq/email", to: "thematiq/admin#update_email", as: :admin_thematiq_email
  post "admin/thematiq/footer", to: "thematiq/admin#update_footer_links", as: :admin_thematiq_footer
  post "admin/thematiq/marker", to: "thematiq/admin#update_environment_marker", as: :admin_thematiq_marker
  post "admin/thematiq/deprecations", to: "thematiq/admin#update_deprecation", as: :admin_thematiq_deprecations
  get "thematiq/api/v1/deprecations", to: "thematiq/api#deprecations", as: :thematiq_api_deprecations, format: false
  post "admin/thematiq/scopes", to: "thematiq/admin#update_scopes", as: :admin_thematiq_scopes
  get "admin/thematiq/history.csv", to: "thematiq/admin#history_export", as: :admin_thematiq_history_export, format: false
  get "admin/thematiq/history", to: "thematiq/admin#history", as: :admin_thematiq_history
  get "admin/thematiq/bundle", to: "thematiq/admin#bundle_export", as: :admin_thematiq_bundle
  get "admin/thematiq/playground", to: "thematiq/admin#playground", as: :admin_thematiq_playground
  post "admin/thematiq/playground", to: "thematiq/admin#component_preview"
  get "admin/thematiq/compliance", to: "thematiq/admin#compliance", as: :admin_thematiq_compliance
  get "admin/thematiq/health", to: "thematiq/admin#health", as: :admin_thematiq_health, defaults: { format: :json }
  post "admin/thematiq/bundle", to: "thematiq/admin#bundle_import"
  get "admin/thematiq/history/:id", to: "thematiq/admin#history_version", as: :admin_thematiq_history_version, constraints: { id: /\d{1,12}/ }
  post "admin/thematiq/history/:id", to: "thematiq/admin#restore", constraints: { id: /\d{1,12}/ }

  # The design system of one project and of its modules. For a project admin with "Choose design system".
  get "projects/:project_id/settings/design", to: "thematiq/project_design#show", as: :project_settings_thematiq_design
  post "projects/:project_id/settings/design", to: "thematiq/project_design#update"

  # Read endpoints for other apps, for anyone signed in (docs/api.md). And thematiq's shell-tokens answer, public.
  get "thematiq/api/v1/sets", to: "thematiq/api#sets", as: :thematiq_api_sets, format: false
  get "thematiq/api/v1/sets/:id", to: "thematiq/api#set", as: :thematiq_api_set, format: false, constraints: { id: /[A-Za-z0-9][A-Za-z0-9._-]{0,63}/ }
  get "thematiq/api/v1/sets/:id/stylesheet.css", to: "thematiq/api#stylesheet", as: :thematiq_api_stylesheet, format: false,
                                                 constraints: { id: /[A-Za-z0-9][A-Za-z0-9._-]{0,63}/ }
  get "thematiq/api/v1/sets/:id/manifest", to: "thematiq/api#manifest", as: :thematiq_api_manifest, format: false,
                                           constraints: { id: /[A-Za-z0-9][A-Za-z0-9._-]{0,63}/ }
  get "thematiq/api/v1/contrast", to: "thematiq/api#contrast", as: :thematiq_api_contrast, format: false
  get "thematiq/metrics", to: "thematiq/metrics#show", as: :thematiq_metrics, format: false
  get "thematiq/api/shell-tokens", to: "thematiq/shell_tokens#show", as: :thematiq_shell_tokens, format: false

  # The uploaded files of the design systems. Public, and only for an id of 64 hex characters.
  get "thematiq/files/:token", to: "thematiq/files#show", constraints: { token: /[0-9a-f]{64}/ }, format: false,
                               as: :thematiq_file
end
