# frozen_string_literal: true

module Thematiq
  # The "Thematiq design" page in the administration. Admins only.
  class AdminController < ApplicationController
    before_action :require_admin
    before_action :load_state

    layout "admin"
    menu_item :thematiq_design

    def show; end

    private

    def load_state
      @store = OpenProject::Thematiq::Store.new
    end
  end
end
