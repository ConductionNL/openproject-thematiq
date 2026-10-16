# frozen_string_literal: true

module Thematiq
  # A shared light or dark choice (sco-suite-wide-appearance): another product, such as Nextcloud with thematiq, links a
  # signed-in person here to set their own OpenProject choice the same way, and back. No connection between the products:
  # only a link the person follows. Off until an administrator turns it on; it changes nothing but that person's choice.
  #
  #   GET /thematiq/appearance?mode=light|dark|system&return_to=<a path here, or an address under the Nextcloud address>
  class AppearanceController < ApplicationController
    before_action :require_login
    authorization_checked! :show

    MODES = { "light" => "light", "dark" => "dark", "system" => "sync_with_os" }.freeze

    def show
      store = OpenProject::Thematiq::Store.new
      return render_404 unless store.appearance_link_enabled?

      theme = MODES[params[:mode].to_s]
      return render_400 unless theme

      preference = User.current.pref
      preference.theme = theme
      preference.save
      return_to = params[:return_to]
      if (path = OpenProject::Thematiq::ReturnTo.path(return_to))
        redirect_to path
      elsif (address = OpenProject::Thematiq::ReturnTo.nextcloud(return_to, store.nextcloud_url))
        redirect_to address, allow_other_host: true
      else
        redirect_to home_path
      end
    end
  end
end
