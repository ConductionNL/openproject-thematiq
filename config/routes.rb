# frozen_string_literal: true

Rails.application.routes.draw do
  scope "admin/thematiq", as: "admin_thematiq", controller: "thematiq/admin" do
    get "/", action: :show, as: ""
    post "/", action: :update
    post "refresh", action: :refresh, as: "refresh"
  end
end
