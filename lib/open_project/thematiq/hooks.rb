# frozen_string_literal: true

module OpenProject
  module Thematiq
    # Every create action of a project opens core's create dialog. See Shell::CreateDialog.
    # A listener has one method per hook, so this addition to the end of the body is a listener of its own.
    class CreateDialogHooks < OpenProject::Hook::ViewListener
      render_on :view_layouts_base_body_bottom, partial: "thematiq/shell/create_dialog"
    end

    # OpenProject has two places to add to the head:
    #
    #   view_layouts_base_html_meta  in the shared head partial, so in layouts/base and layouts/only_logo.
    #                                It comes before OpenProject's stylesheets.
    #   view_layouts_base_html_head  in layouts/base only. It comes after OpenProject's stylesheets.
    #
    # The first gets the variable layer in its "early" form, which does not rely on source order.
    # That is what styles the pages on only_logo: error pages, the external link warning and OAuth consent.
    # The second gets everything, as before. On a base page both are present and the later one decides.
    class Hooks < OpenProject::Hook::ViewListener
      render_on :view_layouts_base_html_meta, partial: "thematiq/hooks/meta"
      render_on :view_layouts_base_html_head, partial: "thematiq/hooks/head"

      # Core calls this hook at the top of the app switcher dialog, before its own module list
      # (lib/redmine/menu_manager/top_menu/module_menu.rb). The module list itself stays core's:
      # it comes from OpenProject's menu and permission helpers.
      render_on :module_menu_dialog_content_before, partial: "thematiq/shell/app_switcher_nextcloud"

      # E-mail in the house style, when an admin turned it on: a band before the content and a block after it.
      render_on :view_layouts_mailer_html_before_content, partial: "thematiq/hooks/mail_header"
      render_on :view_layouts_mailer_html_after_content, partial: "thematiq/hooks/mail_footer"

      # The end of the body: the script of the two-layer project menu.
      render_on :view_layouts_base_body_bottom, partial: "thematiq/shell/body_bottom"
    end
  end
end
