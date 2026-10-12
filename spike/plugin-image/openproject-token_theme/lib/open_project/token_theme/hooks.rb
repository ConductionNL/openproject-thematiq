module OpenProject::TokenTheme
  class Hooks < OpenProject::Hook::ViewListener
    render_on :view_layouts_base_html_head, partial: "hooks/token_theme/head"
  end
end
