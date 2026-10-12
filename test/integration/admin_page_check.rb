# frozen_string_literal: true

# A request level check of the admin page against a running development instance.
# The OpenProject image ships without the test gems, so this is a script for `rails runner`
# and not an RSpec file. It signs in through the real login form, so the real CSRF check,
# the real admin guard and the real layout are in play.
#
# Run it inside the container, see docs/development.md:
#   THEMATIQ_CHECK_PASSWORD=<admin password> THEMATIQ_CHECK_HOST=localhost:8080 \
#     bin/rails runner /app/custom-plugins/openproject-thematiq/test/integration/admin_page_check.rb
#
# It creates one temporary non-admin user, restores the plugin's settings at the end
# and exits 1 when a check fails. Do not run it against an instance people use.

HOST = ENV.fetch("THEMATIQ_CHECK_HOST")
ADMIN_PASSWORD = ENV.fetch("THEMATIQ_CHECK_PASSWORD")
MEMBER_LOGIN = "thematiq-check-member"
MEMBER_PASSWORD = "Check-#{SecureRandom.hex(8)}-Aa1!"

$failures = []
$checks = 0

def check(label)
  $checks += 1
  ok = yield
  puts "#{ok ? 'ok  ' : 'FAIL'} #{label}"
  $failures << label unless ok
rescue StandardError => e
  puts "FAIL #{label} (#{e.class}: #{e.message})"
  $failures << label
end

def session_for(login = nil, password = nil)
  session = ActionDispatch::Integration::Session.new(Rails.application)
  session.host! HOST
  return session unless login

  session.get "/login"
  token = session.response.body[/name="authenticity_token" value="([^"]+)"/, 1]
  session.post "/login", params: { username: login, password:, authenticity_token: CGI.unescapeHTML(token.to_s) }
  # OpenProject walks through its authentication stages with redirects before the session is signed in.
  5.times { session.response.redirect? ? session.follow_redirect! : break }
  session
end

# The CSRF token of one form on a page. Rails binds a token to one form action.
def form_token(session, path, form_id)
  session.get path
  CGI.unescapeHTML(session.response.body[/<form[^>]*id="#{form_id}".*?name="authenticity_token" value="([^"]+)"/m, 1].to_s)
end

def head_style(session)
  session.response.body[%r{<style id="openproject-thematiq".*?</style>}m].to_s
end

saved_settings = Setting.plugin_openproject_thematiq
member = User.find_by(login: MEMBER_LOGIN) || User.new(login: MEMBER_LOGIN)
member.assign_attributes(firstname: "Thematiq", lastname: "Check", mail: "thematiq-check@example.org", admin: false,
                         status: :active, password: MEMBER_PASSWORD, password_confirmation: MEMBER_PASSWORD,
                         force_password_change: false)
member.save!

begin
  # 1. Who may open the page
  anonymous = session_for
  anonymous.get "/admin/thematiq"
  check("anonymous is sent to the login page") { anonymous.response.status == 302 && anonymous.response.location.include?("/login") }

  as_member = session_for(MEMBER_LOGIN, MEMBER_PASSWORD)
  as_member.get "/admin/thematiq"
  check("a signed in non-admin gets 403") { as_member.response.status == 403 }

  admin = session_for("admin", ADMIN_PASSWORD)
  admin.get "/admin/thematiq"
  check("an admin gets 200") { admin.response.status == 200 }
  body = admin.response.body
  check("the admin menu has the item") { body.include?("Thematiq design") }
  check("the page names the active design system") { body.include?("Active design system") && body.include?("Cunningham") }
  check("the head style carries the Cunningham primary colour") { head_style(admin).include?("--header-bg-color: #1a67a3;") }

  # 2. The removed link stays removed
  check("no background job of the plugin is scheduled") { Rails.application.config.good_job.cron.keys.grep(/Thematiq/).empty? }
  check("the plugin has no HTTP client") { !defined?(OpenProject::Thematiq::Tokens::Client) }

  # 3. The picker
  catalogue = OpenProject::Thematiq::Catalogue.bundled
  last = catalogue.sets.last
  check("the catalogue in the gem loads without an error") { catalogue.error.nil? && catalogue.skipped.zero? }
  check("the picker lists every design system") { catalogue.sets.all? { |set| body.include?(%(id="thematiq-set-#{set.id}")) } }
  check("the picker has one small picture per design system") { body.scan('class="thematiq-thumb"').size == catalogue.sets.size }
  check("the picker says which one is active") { body.include?("Active now: <strong>Cunningham</strong>") }
  check("the picker has a labelled search field") { body.include?('id="thematiq-search"') && body.include?("Search design systems") }
  check("the picker counts the sets") { body.include?("#{catalogue.sets.size} of #{catalogue.sets.size} design systems") }

  admin.get "/admin/thematiq", params: { q: "no design system is called this" }
  check("a search without a match says so") { admin.response.status == 200 && admin.response.body.include?("No design system has that name") }
  admin.get "/admin/thematiq", params: { q: %(<script>alert(1)</script>") }
  check("a hostile search is escaped") { !admin.response.body.include?("<script>alert(1)</script>") }
  admin.get "/admin/thematiq", params: { q: last.name }
  check("a search by name finds the set") { admin.response.body.include?(%(id="thematiq-set-#{last.id}")) }

  as_member.post "/admin/thematiq", params: { set_id: last.id }
  check("a non-admin cannot apply a design system") { [403, 422].include?(as_member.response.status) }
  check("the non-admin post changed nothing") { Setting.plugin_openproject_thematiq == saved_settings }

  throwaway = session_for("admin", ADMIN_PASSWORD)
  throwaway.post "/admin/thematiq", params: { set_id: last.id }
  check("a post without a CSRF token is refused") { throwaway.response.status == 422 }

  admin.post "/admin/thematiq", params: { set_id: "no-such-set", authenticity_token: form_token(admin, "/admin/thematiq", "thematiq-picker-form") }
  admin.follow_redirect!
  check("an unknown design system is refused") { admin.response.body.include?("Choose a design system from the list first.") }

  admin.post "/admin/thematiq", params: { set_id: last.id, authenticity_token: form_token(admin, "/admin/thematiq", "thematiq-picker-form") }
  admin.follow_redirect!
  check("apply makes the chosen design system active") { OpenProject::Thematiq::Store.new.active_token_set.id == last.id }
  check("the page says so") { admin.response.body.include?("is now the active design system") }
  check("the head style carries its primary colour") { head_style(admin).include?("--header-bg-color: #{last['primary']};") }
ensure
  Setting.plugin_openproject_thematiq = saved_settings
  member.destroy
end

puts "#{$checks} checks, #{$failures.size} failures"
exit($failures.empty? ? 0 : 1)
