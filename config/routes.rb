# frozen_string_literal: true

Rails.application.routes.draw do
  get "admin/thematiq", to: "thematiq/admin#show", as: :admin_thematiq
  post "admin/thematiq", to: "thematiq/admin#update"
  get "admin/thematiq/custom", to: "thematiq/admin#edit", as: :admin_thematiq_custom
  post "admin/thematiq/custom", to: "thematiq/admin#update_custom"
end
