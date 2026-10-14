# frozen_string_literal: true

require "erb"
require "open_project/thematiq/contrast"

module OpenProject
  module Thematiq
    # E-mail in the house style (sur-email, sur-email-footer). Mail clients drop style sheets, so everything is inline,
    # from validated token values. Text an administrator typed is escaped and keeps its lines. Off until an admin
    # turns it on: OpenProject's own e-mail stays as it is until then.
    module Email
      MAX_FOOTER = 1000

      module_function

      # The band at the top of every e-mail: the primary colour, the app's title and the logo when there is one.
      # logo_url: an absolute address, or nil.
      def header_html(token_set, title:, logo_url: nil)
        primary = token_set["primary"]
        text = Contrast.best_on(primary, ["#ffffff", token_set["ink"], "#1b1c1d"])
        font = token_set["font-family"].to_s.delete('"')
        logo = logo_url ? %(<img src="#{h(logo_url)}" alt="" height="28" style="height: 28px; width: auto; vertical-align: middle; margin-right: 12px; border: 0;">) : ""
        <<~HTML.strip
          <table class="thematiq-mail-header" role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width: 700px; width: 100%; margin: 0 auto 16px; border-collapse: collapse;">
            <tr><td style="background: #{primary}; color: #{text}; padding: 14px 20px; font-family: #{h(font)}; font-size: 18px; font-weight: 700;">#{logo}#{h(title)}</td></tr>
          </table>
        HTML
      end

      # The block under the content: the organisation's own text, its lines kept, and the legal links.
      def footer_html(token_set, text:, links:, labels:)
        lines = text.to_s.strip.empty? ? "" : h(text.to_s.strip[0, MAX_FOOTER]).gsub(/\r?\n/, "<br>")
        link_html = links.map { |kind, address| %(<a href="#{h(address)}" style="color: #{token_set['link']};">#{h(labels.fetch(kind, kind))}</a>) }.join(" &middot; ")
        return "" if lines.empty? && link_html.empty?

        <<~HTML.strip
          <table class="thematiq-mail-footer" role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width: 700px; width: 100%; margin: 16px auto 0; border-collapse: collapse;">
            <tr><td style="border-top: 3px solid #{token_set['primary']}; padding: 12px 0; color: #{token_set['muted']}; font-family: #{h(token_set['font-family'].to_s.delete('"'))}; font-size: 13px;">#{[lines, link_html].reject(&:empty?).join('<br><br>')}</td></tr>
          </table>
        HTML
      end

      def h(text)
        ERB::Util.html_escape(text.to_s)
      end
    end
  end
end
