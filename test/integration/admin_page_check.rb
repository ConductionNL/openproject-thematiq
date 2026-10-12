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

require "socket"
require "json"

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

def form_token(session, form_id)
  session.get "/admin/thematiq"
  CGI.unescapeHTML(session.response.body[/<form[^>]*id="#{form_id}".*?name="authenticity_token" value="([^"]+)"/m, 1].to_s)
end

# A local endpoint that answers like thematiq, with one hostile token.
def start_endpoint
  server = TCPServer.new("127.0.0.1", 0)
  body = JSON.generate(
    "version" => 1, "id" => "check", "name" => "Check <b>set</b>", "revision" => "check-1",
    "tokens" => { "primary" => "#aa0055", "action" => "red; } body { display:none", "radius" => "8px" },
    "logo" => { "url" => nil, "inverse_url" => nil }
  )
  Thread.new do
    loop do
      socket = server.accept
      nil while (line = socket.gets) && line != "\r\n"
      socket.write "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
      socket.close
    rescue IOError
      break
    end
  end
  ["http://127.0.0.1:#{server.addr[1]}", server]
end

saved_settings = Setting.plugin_openproject_thematiq
member = User.find_by(login: MEMBER_LOGIN) || User.new(login: MEMBER_LOGIN)
member.assign_attributes(firstname: "Thematiq", lastname: "Check", mail: "thematiq-check@example.org", admin: false,
                         status: :active, password: MEMBER_PASSWORD, password_confirmation: MEMBER_PASSWORD,
                         force_password_change: false)
member.save!
endpoint, server = start_endpoint

begin
  # 1. Who may open the page
  anonymous = session_for
  anonymous.get "/admin/thematiq"
  check("anonymous is sent to the login page") { anonymous.response.status == 302 && anonymous.response.location.include?("/login") }

  as_member = session_for(MEMBER_LOGIN, MEMBER_PASSWORD)
  as_member.get "/admin/thematiq"
  check("a signed in non-admin gets 403") { as_member.response.status == 403 }
  as_member.post "/admin/thematiq", params: { base_url: endpoint }
  check("a non-admin cannot save, with or without a token") { [403, 422].include?(as_member.response.status) }
  check("the non-admin post changed nothing") { Setting.plugin_openproject_thematiq == saved_settings }

  admin = session_for("admin", ADMIN_PASSWORD)
  admin.get "/admin/thematiq"
  check("an admin gets 200") { admin.response.status == 200 }
  body = admin.response.body
  check("the page has the address field") { body.include?('id="thematiq-base-url"') }
  check("the page has the three actions") { ["Save", "Check connection", "Refresh now"].all? { |text| body.include?(text) } }
  check("the page shows name, revision, last fetched") { ["Name", "Revision", "Last fetched", "Source"].all? { |text| body.include?(text) } }
  check("the admin menu has the item") { body.include?("Thematiq design") }

  # 2. CSRF. OpenProject ends the session on a failed check, so this uses a session of its own.
  throwaway = session_for("admin", ADMIN_PASSWORD)
  throwaway.post "/admin/thematiq", params: { base_url: endpoint }
  check("a post without a CSRF token is refused") { throwaway.response.status == 422 }
  check("the refused post changed nothing") { Setting.plugin_openproject_thematiq == saved_settings }

  # 3. Empty address: bundled default
  admin.post "/admin/thematiq", params: { base_url: "", authenticity_token: form_token(admin, "thematiq-connection-form") }
  admin.follow_redirect!
  check("with no address the page says the bundled default is in use") do
    admin.response.body.include?("The bundled default is in use. No Nextcloud address is set.")
  end

  # 4. Invalid address
  admin.post "/admin/thematiq", params: { base_url: "javascript:alert(1)", authenticity_token: form_token(admin, "thematiq-connection-form") }
  check("an invalid address is refused with 422") { admin.response.status == 422 && admin.response.body.include?("Enter a full address") }
  check("the invalid address is not stored") { OpenProject::Thematiq::Store.new.base_url == "" }

  # 5. Check connection stores nothing
  admin.post "/admin/thematiq", params: { base_url: endpoint, check: "1", authenticity_token: form_token(admin, "thematiq-connection-form") }
  check("check connection reports the offered design system") { admin.response.status == 200 && admin.response.body.include?("The connection works.") }
  check("check connection escapes the name") { admin.response.body.include?("Check &lt;b&gt;set&lt;/b&gt;") && !admin.response.body.include?("Check <b>set</b>") }
  check("check connection stores nothing") { OpenProject::Thematiq::Store.new.base_url == "" && OpenProject::Thematiq::Store.new.token_set.nil? }

  admin.post "/admin/thematiq", params: { base_url: "http://127.0.0.1:9", check: "1", authenticity_token: form_token(admin, "thematiq-connection-form") }
  check("check connection reports an unreachable address") { admin.response.body.include?("The address could not be reached.") }

  # 6. Save fetches, and the page head carries the tokens
  admin.post "/admin/thematiq", params: { base_url: endpoint, authenticity_token: form_token(admin, "thematiq-connection-form") }
  admin.follow_redirect!
  body = admin.response.body
  style = body[%r{<style id="openproject-thematiq".*?</style>}m].to_s
  check("save stores the address and the token set") { OpenProject::Thematiq::Store.new.token_set&.revision == "check-1" }
  check("the page shows the revision and the source") { body.include?("check-1") && body.include?("Thematiq") }
  check("the head style carries the fetched primary colour") { style.include?("--header-bg-color: #aa0055;") }
  check("the hostile token did not reach the page") { !style.include?("display:none") && style.include?("--primary-button-color: #1f883d;") }
  check("the page names the refused token") { body.include?("replaced by the bundled default: action.") }
  check("the style tag is closed once") { style.scan("</style>").size == 1 && !style.sub(/\A<style[^>]*>/, "").sub(%r{</style>\z}, "").include?("<") }

  # 7. Refresh now
  admin.post "/admin/thematiq/refresh", params: { authenticity_token: form_token(admin, "thematiq-refresh-form") }
  admin.follow_redirect!
  check("refresh now reports success") { admin.response.body.include?("Refreshed.") }

  # 8. A failing fetch keeps the last good set
  server.close
  admin.post "/admin/thematiq/refresh", params: { authenticity_token: form_token(admin, "thematiq-refresh-form") }
  admin.follow_redirect!
  body = admin.response.body
  check("a failed refresh says so") { body.include?("The address could not be reached.") }
  check("a failed refresh keeps the design system") { body.include?("check-1") && body.include?("--header-bg-color: #aa0055;") }
ensure
  server.close unless server.closed?
  Setting.plugin_openproject_thematiq = saved_settings
  member.destroy
end

puts "#{$checks} checks, #{$failures.size} failures"
exit($failures.empty? ? 0 : 1)
