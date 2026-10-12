# frozen_string_literal: true

Rails.application.routes.draw do
  get "admin/thematiq", to: "thematiq/admin#show", as: :admin_thematiq
end
