# frozen_string_literal: true

module OpenProject
  module Thematiq
    # Only layouts/base.html.erb calls this hook. Pages on the only_logo layout
    # (sign in, for example) do not get the stylesheet.
    class Hooks < OpenProject::Hook::ViewListener
      render_on :view_layouts_base_html_head, partial: "thematiq/hooks/head"
    end
  end
end
