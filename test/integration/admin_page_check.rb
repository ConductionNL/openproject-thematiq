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
  default_name = OpenProject::Thematiq::Catalogue.bundled.default.name
  check("the page names the active design system") { body.include?("Active now: <strong>#{ERB::Util.html_escape(default_name)}</strong>") }
  check("the head style carries the Cunningham primary colour") { head_style(admin).include?("--header-bg-color: #{OpenProject::Thematiq::Catalogue.bundled.default['primary']};") }

  # 1b. Which pages carry the style tags
  anonymous.get "/login"
  check("the sign in page carries the full style tag") do
    anonymous.response.status == 200 && anonymous.response.body.include?('<style id="openproject-thematiq"') &&
      anonymous.response.body.include?('<style id="openproject-thematiq-early"')
  end
  check("the early style tag comes before OpenProject's stylesheets and the full one after") do
    page = anonymous.response.body
    early = page.index('id="openproject-thematiq-early"')
    sheet = page.index('rel="stylesheet"')
    full = page.index('<style id="openproject-thematiq"')
    early && sheet && full && early < sheet && sheet < full
  end
  admin.get "/this-page-does-not-exist-#{SecureRandom.hex(4)}"
  check("an error page carries the early style tag") do
    admin.response.status == 404 && admin.response.body.include?('<style id="openproject-thematiq-early"')
  end
  %w[/thematiq/logos/zuiddrecht.svg /thematiq/fonts/inter-latin-400-normal.woff2 /thematiq/fonts/OFL.txt].each do |path|
    anonymous.get path
    check("the plugin serves #{path} without a sign in") { anonymous.response.status == 200 && anonymous.response.body.bytesize > 500 }
  end
  anonymous.get "/thematiq/logos/..%2F..%2F..%2Fconfig%2Fdatabase.yml"
  check("the static handler does not leave its folder") { anonymous.response.status != 200 }

  # 2. The removed link stays removed
  check("no background job of the plugin is scheduled") { Rails.application.config.good_job.cron.keys.grep(/Thematiq/).empty? }
  check("the plugin has no HTTP client") { !defined?(OpenProject::Thematiq::Tokens::Client) }

  # 3. The picker
  catalogue = OpenProject::Thematiq::Catalogue.bundled
  last = catalogue.sets.last
  check("the catalogue in the gem loads without an error") { catalogue.error.nil? && catalogue.skipped.zero? }
  check("the picker lists every design system") { catalogue.sets.all? { |set| body.include?(%(id="thematiq-set-#{set.id}")) } }
  check("the picker has one small picture per design system") { body.scan('class="thematiq-thumb"').size == catalogue.sets.size }
  check("the picker marks the active one") { body.include?('id="thematiq-set-cunningham"') && body.scan(/Label[^>]*>\s*Active\s*</).size == 1 }
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

  # 4. The editor
  default = catalogue.default
  # OpenProject ended the non-admin's session when its post without a token was refused, so it signs in again.
  as_member = session_for(MEMBER_LOGIN, MEMBER_PASSWORD)
  as_member.get "/admin/thematiq/custom"
  check("a non-admin cannot open the editor") { as_member.response.status == 403 }

  admin.get "/admin/thematiq/custom", params: { from: default.id }
  body = admin.response.body
  check("an admin opens the editor") { admin.response.status == 200 && body.include?('id="thematiq-editor-form"') }
  check("the editor has a field for each of the eighteen tokens") do
    OpenProject::Thematiq::Tokens::TokenSet::KINDS.each_key.all? { |key| body.include?(%(id="thematiq-token-#{key}")) }
  end
  check("the editor shows the shell preview") { body.include?('data-test-selector="thematiq-shell-preview"') }

  token = form_token(admin, "/admin/thematiq/custom", "thematiq-editor-form")
  admin.post "/admin/thematiq/custom", params: { name: "Check style", based_on: default.id, preview: "1",
                                                 tokens: { "primary" => "#aa0055" }, authenticity_token: token }
  check("preview draws the typed colour") { admin.response.status == 200 && admin.response.body.include?("background: #aa0055") }
  check("preview stores nothing") { OpenProject::Thematiq::Store.new.custom_draft.nil? }

  hostile = 'red; } body { display:none'
  token = form_token(admin, "/admin/thematiq/custom", "thematiq-editor-form")
  admin.post "/admin/thematiq/custom", params: { name: "Check style", based_on: default.id, save: "1",
                                                 tokens: { "primary" => hostile, "radius" => "12px" }, authenticity_token: token }
  body = admin.response.body
  check("a hostile value is refused with 422") { admin.response.status == 422 && body.include?("This is not a colour the plugin accepts") }
  check("the refused value is not stored") { OpenProject::Thematiq::Store.new.custom_draft.nil? }
  check("the refused value is shown escaped, in its field only") do
    body.scan(hostile).size == 1 && body.include?(%(value="#{hostile}")) && !head_style(admin).include?("display:none")
  end

  token = form_token(admin, "/admin/thematiq/custom", "thematiq-editor-form")
  admin.post "/admin/thematiq/custom", params: { name: "Check style", based_on: default.id, save: "1",
                                                 tokens: { "primary" => "#aa0055", "radius" => "12px" }, authenticity_token: token }
  admin.follow_redirect!
  body = admin.response.body
  store = OpenProject::Thematiq::Store.new
  check("save and apply stores the overrides") { store.custom_draft&.overrides == { "primary" => "#aa0055", "radius" => "12px" } }
  check("the custom design system is active") { store.custom_active? && store.active_token_set.name == "Check style" }
  check("the head style carries the overrides") { head_style(admin).include?("--header-bg-color: #aa0055;") && head_style(admin).include?("--thematiq-radius: 12px;") }
  check("the head style keeps the base for the rest") { head_style(admin).include?("--primary-button-color: #{default['action']};") }
  check("the picker lists the custom design system") { body.include?('id="thematiq-set-custom"') && body.include?("Check style") }

  token = form_token(admin, "/admin/thematiq/custom", "thematiq-editor-form")
  admin.post "/admin/thematiq/custom", params: { name: "Check style", based_on: default.id, reset: "primary",
                                                 tokens: { "primary" => "#aa0055", "radius" => "12px" }, authenticity_token: token }
  check("reset of one token clears its field and saves nothing") do
    admin.response.status == 200 && !admin.response.body.include?('value="#aa0055"') && admin.response.body.include?('value="12px"') &&
      OpenProject::Thematiq::Store.new.custom_draft.overrides.key?("primary")
  end

  token = form_token(admin, "/admin/thematiq/custom", "thematiq-editor-form")
  admin.post "/admin/thematiq/custom", params: { name: "Check style", based_on: default.id, reset_all: "1",
                                                 tokens: { "primary" => "#aa0055" }, authenticity_token: token }
  check("reset all clears every field") { admin.response.status == 200 && !admin.response.body.include?('value="#aa0055"') }

  admin.post "/admin/thematiq", params: { set_id: default.id, authenticity_token: form_token(admin, "/admin/thematiq", "thematiq-picker-form") }
  check("picking a catalogue set turns the custom one off and keeps it") do
    s = OpenProject::Thematiq::Store.new
    !s.custom_active? && s.custom_draft&.name == "Check style"
  end

  throwaway = session_for("admin", ADMIN_PASSWORD)
  throwaway.post "/admin/thematiq/custom", params: { name: "x", based_on: default.id, save: "1" }
  check("an editor post without a CSRF token is refused") { throwaway.response.status == 422 }

  token = form_token(admin, "/admin/thematiq/custom", "thematiq-editor-form")
  admin.post "/admin/thematiq/custom", params: { delete: "1", authenticity_token: token }
  check("delete removes the custom design system") { OpenProject::Thematiq::Store.new.custom_draft.nil? }

  # 5. Export and import
  require "tempfile"
  upload = lambda do |content|
    file = Tempfile.new(["thematiq-check", ".json"])
    file.binmode
    file.write(content)
    file.close
    Rack::Test::UploadedFile.new(file.path, "application/json")
  end

  as_member.get "/admin/thematiq/export", params: { id: default.id }
  check("a non-admin cannot export") { as_member.response.status == 403 }

  admin.get "/admin/thematiq/export", params: { id: default.id }
  exported = admin.response.body
  check("export sends a JSON attachment") do
    admin.response.status == 200 && admin.response.headers["Content-Disposition"].to_s.include?("attachment") &&
      admin.response.media_type == "application/json"
  end
  check("the export is the set shape") { JSON.parse(exported).keys == %w[id name tokens logo] }
  admin.get "/admin/thematiq/export", params: { id: "no-such-set" }
  check("export of an unknown design system gives 404") { admin.response.status == 404 }
  admin.get "/admin/thematiq/export", params: { id: "custom" }
  check("export of a custom design system that does not exist gives 404") { admin.response.status == 404 }

  import = lambda do |content|
    token = form_token(admin, "/admin/thematiq", "thematiq-import-form")
    admin.post "/admin/thematiq/import", params: { file: upload.call(content), authenticity_token: token }
    admin.follow_redirect!
    admin.response.body
  end

  good = JSON.parse(exported).merge("id" => "moved", "name" => "Moved style")
  good["tokens"]["primary"] = "#aa0055"
  body = import.call(JSON.generate(good))
  store = OpenProject::Thematiq::Store.new
  check("import stores the file as the custom design system") { store.custom_draft&.name == "Moved style" && store.custom_set["primary"] == "#aa0055" }
  check("import does not apply it") { !store.custom_active? && body.include?("is added as a custom design system") }

  { "a hostile token value" => JSON.generate(good.merge("tokens" => good["tokens"].merge("action" => "red; } body { display:none"))),
    "an unknown key" => JSON.generate(good.merge("script" => "<script>alert(1)</script>")),
    "a file that is not JSON" => "<html><script>alert(1)</script></html>",
    "a file over the size cap" => JSON.generate(good) + (" " * 70_000),
    "an empty file" => "" }.each do |label, content|
    body = import.call(content)
    check("import refuses #{label} and says why") { ["Nothing was imported", "is not a design system file", "Choose a file first", "The file is too large"].any? { |text| body.include?(text) } }
    check("after #{label} the stored custom design system is unchanged") { OpenProject::Thematiq::Store.new.custom_set["primary"] == "#aa0055" }
    check("after #{label} nothing hostile is on the page") { !body.include?("<script>alert(1)</script>") && !head_style(admin).include?("display:none") }
  end

  body = import.call(JSON.generate(good.merge("name" => "Second moved style")))
  store = OpenProject::Thematiq::Store.new
  check("a second import is added and does not replace the first") do
    store.custom_drafts.map(&:name).sort == ["Moved style", "Second moved style"] && body.include?('id="thematiq-set-custom-2"')
  end
  admin.get "/admin/thematiq/custom", params: { id: "custom-2" }
  check("the editor opens the second custom design system") { admin.response.body.include?('value="Second moved style"') && admin.response.body.include?('name="id" value="custom-2"') }
  admin.post "/admin/thematiq/custom", params: { id: "custom-2", delete: "1", authenticity_token: form_token(admin, "/admin/thematiq/custom?id=custom-2", "thematiq-editor-form") }
  check("deleting the second leaves the first") { OpenProject::Thematiq::Store.new.custom_drafts.map(&:name) == ["Moved style"] }

  zuiddrecht_file = OpenProject::Thematiq::Transfer.export(catalogue.find("zuiddrecht"))
  import.call(zuiddrecht_file)
  check("an imported set keeps the bundled logo of the set it came from") do
    moved = OpenProject::Thematiq::Store.new.custom_drafts.find { |draft| draft.name == catalogue.find("zuiddrecht").name }
    moved && OpenProject::Thematiq::Assets.bundled.logo_url(moved.token_set) == "/thematiq/logos/zuiddrecht-dark.svg"
  end

  throwaway = session_for("admin", ADMIN_PASSWORD)
  throwaway.post "/admin/thematiq/import", params: { file: upload.call(JSON.generate(good)) }
  check("an import without a CSRF token is refused") { throwaway.response.status == 422 }

  admin.get "/admin/thematiq/export", params: { id: "custom" }
  check("the custom design system exports and imports back to the same tokens") do
    OpenProject::Thematiq::Transfer.import(admin.response.body).tokens == OpenProject::Thematiq::Store.new.custom_set.tokens
  end

  # 6. The Nextcloud address for the app switcher
  shell_post = lambda do |value|
    token = form_token(admin, "/admin/thematiq", "thematiq-shell-form")
    admin.post "/admin/thematiq/shell", params: { nextcloud_url: value, authenticity_token: token }
    admin.follow_redirect!
    admin.response.body
  end
  body = shell_post.call("https://cloud.example.org/")
  check("the Nextcloud address is saved and the shell reads it") { OpenProject::Thematiq::Shell.nextcloud_url == "https://cloud.example.org" }
  check("the field shows the saved address") { body.include?('value="https://cloud.example.org"') }
  body = shell_post.call("javascript:alert(1)")
  check("an address that is not http is refused and the old one stays") do
    body.include?("Enter a full address") && OpenProject::Thematiq::Shell.nextcloud_url == "https://cloud.example.org"
  end
  shell_post.call("")
  check("an empty address clears it") { OpenProject::Thematiq::Shell.nextcloud_url.nil? }

  # 7. The public endpoint for uploaded files. The rows are stored through the model here,
  #    so this part checks the table, the model and the endpoint without the admin form.
  require_relative "../uploads/samples"
  uploads = OpenProject::Thematiq::Uploads
  check_set = "custom-9999"
  check("the table of the plugin exists") { Thematiq::Upload.ready? && Thematiq::Upload.column_names.include?("data") }
  Thematiq::Upload.remove_set(check_set)

  stored = Thematiq::Upload.store!(set_id: check_set, result: uploads::Inspector.inspect_upload("logo", UploadSamples.svg("hostile-script")), label: "x.svg")
  logo = stored.to_record
  check("a stored file gets an id of 64 hex characters") { logo && uploads::TOKEN.match?(logo.token) }

  fresh = session_for
  fresh.get logo.url
  served = fresh.response
  check("a file is served without a sign in") { served.status == 200 && served.body.bytesize == logo.byte_size }
  check("the endpoint sets no cookie") { served.headers["Set-Cookie"].blank? }
  check("the served SVG is the rebuilt one, without script") { served.body.include?("<rect") && !served.body.include?("script") }
  check("the content type is the one decided at upload") { served.headers["Content-Type"] == "image/svg+xml" }
  check("the answer says nosniff") { served.headers["X-Content-Type-Options"] == "nosniff" }
  check("the answer has its own content security policy, with no script") do
    served.headers["Content-Security-Policy"] == uploads::Response::POLICY
  end
  check("the answer may be cached and carries an ETag") do
    served.headers["Cache-Control"].to_s.include?("max-age=31536000") && served.headers["ETag"] == %("#{logo.sha256}")
  end
  check("the download name is fixed") { served.headers["Content-Disposition"] == %(inline; filename="logo.svg") }
  fresh.get logo.url, headers: { "If-None-Match" => served.headers["ETag"] }
  check("a browser that holds the file gets 304 and no body") { fresh.response.status == 304 && fresh.response.body.empty? }
  fresh.head logo.url
  check("a HEAD request gets the headers and no body") { fresh.response.status == 200 && fresh.response.body.empty? }

  png = Thematiq::Upload.store!(set_id: check_set, result: uploads::Inspector.inspect_upload("favicon", UploadSamples.png(32, 32))).to_record
  fresh.get png.url
  check("a PNG comes back byte for byte") do
    fresh.response.headers["Content-Type"] == "image/png" && fresh.response.body.b == UploadSamples.png(32, 32)
  end

  replaced = Thematiq::Upload.store!(set_id: check_set, result: uploads::Inspector.inspect_upload("logo", UploadSamples.png(200, 50))).to_record
  check("a replaced file gets a new address") { replaced.token != logo.token && Thematiq::Upload.records_for(check_set).count { |r| r.kind == "logo" } == 1 }
  fresh.get logo.url
  check("the old address stops answering") { fresh.response.status == 404 }

  ["/thematiq/files/#{'0' * 64}", "/thematiq/files/#{replaced.token.upcase}", "/thematiq/files/#{replaced.token}/",
   "/thematiq/files/#{replaced.token}.svg", "/thematiq/files/#{replaced.token[0, 63]}", "/thematiq/files/#{replaced.token}0",
   "/thematiq/files/..%2F..%2F..%2Fconfig%2Fdatabase.yml", "/thematiq/files/../../config/database.yml",
   "/thematiq/files/%2e%2e%2f%2e%2e%2fetc%2fpasswd", "/thematiq/files/#{replaced.id}", "/thematiq/files/",
   "/thematiq/files/#{replaced.token}%00", "/thematiq/files/#{replaced.token}/../../../config/database.yml",
   "/thematiq/files/' OR '1'='1"].each do |path|
    begin
      fresh.get path
      status = fresh.response.status
      body = fresh.response.body
    rescue StandardError => e
      status = e.class.name
      body = ""
    end
    check("#{path[0, 60]} serves nothing (#{status})") do
      status != 200 && !body.include?("adapter:") && !body.include?("root:") && !body.start_with?("\x89PNG".b)
    end
  end
  fresh.post replaced.url
  check("the endpoint takes no POST") { fresh.response.status != 200 }

  Thematiq::Upload.where(set_id: check_set, kind: "logo").update_all(kind: "export_logo")
  fresh.get replaced.url
  check("a row that is not one of the kinds is not served") { fresh.response.status == 404 }
  Thematiq::Upload.remove_set(check_set)
  fresh.get png.url
  check("a removed file is gone") { fresh.response.status == 404 }
ensure
  Thematiq::Upload.remove_set("custom-9999") if defined?(Thematiq::Upload)
  Setting.plugin_openproject_thematiq = saved_settings
  member.destroy
end

puts "#{$checks} checks, #{$failures.size} failures"
exit($failures.empty? ? 0 : 1)
