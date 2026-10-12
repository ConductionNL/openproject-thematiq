# frozen_string_literal: true

Rails.application.routes.draw do
  get "admin/thematiq", to: "thematiq/admin#show", as: :admin_thematiq
  post "admin/thematiq", to: "thematiq/admin#update"
end
