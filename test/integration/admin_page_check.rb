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
# and exits 1 when a check fails. Do not run it against an instance people use: it deletes
# the uploaded files of the custom design systems, and those are not restored.

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
# The checks below expect a fresh install: the default design system and no custom ones.
# The settings that were there come back at the end.
Setting.plugin_openproject_thematiq = {}
fresh_settings = Setting.plugin_openproject_thematiq
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
  check("the non-admin post changed nothing") { Setting.plugin_openproject_thematiq == fresh_settings }

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
  check("the editor has the optional menu field") { body.include?('id="thematiq-token-menu"') }
  check("the editor has its four groups") do
    OpenProject::Thematiq::Editor.groups.all? { |group| body.include?(%(data-thematiq-group="#{group.id}")) }
  end
  check("the preview is drawn with custom properties") { body.include?("--tqp-primary: #{default['primary']}") }
  check("a colour has its contrast line") { body.include?('data-thematiq-check="ink-on-ground"') && body.include?("to 1. That is") }
  check("the script of the editor carries the nonce of the page") do
    tag = body[%r{<script[^>]*>\s*(?://<!\[CDATA\[\s*)?window\.thematiqEditorData}]
    nonce = body[/<meta name="csp-nonce" content="([^"]+)"/, 1]
    tag && nonce && tag.include?(%(nonce="#{nonce}"))
  end

  token = form_token(admin, "/admin/thematiq/custom", "thematiq-editor-form")
  admin.post "/admin/thematiq/custom", params: { name: "Check style", based_on: default.id, preview: "1",
                                                 tokens: { "primary" => "#aa0055" }, authenticity_token: token }
  check("preview draws the typed colour") { admin.response.status == 200 && admin.response.body.include?("--tqp-primary: #aa0055") }
  check("the typed colour is marked as changed") { admin.response.body.match?(/thematiq-editor__field is-changed" data-thematiq-row="primary"/) }
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
  admin.post "/admin/thematiq/custom", params: { name: "Check style", based_on: default.id, reset_group: "branding",
                                                 tokens: { "primary" => "#aa0055", "accent" => "#00aa55", "radius" => "12px" }, authenticity_token: token }
  check("reset of a group clears its fields, keeps the others and saves nothing") do
    admin.response.status == 200 && !admin.response.body.include?('value="#aa0055"') && !admin.response.body.include?('value="#00aa55"') &&
      admin.response.body.include?('value="12px"') && OpenProject::Thematiq::Store.new.custom_draft.overrides.key?("primary")
  end

  token = form_token(admin, "/admin/thematiq/custom", "thematiq-editor-form")
  admin.post "/admin/thematiq/custom", params: { name: "Check style", based_on: default.id, preview: "1",
                                                 tokens: { "menu" => "#102030" }, authenticity_token: token }
  check("a typed menu colour reaches the preview") { admin.response.body.include?("--tqp-menu: #102030") }

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
  admin.post "/admin/thematiq/custom", params: { id: "custom", delete: "1", authenticity_token: token }
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
  check("the export is the set shape") { (%w[id name tokens logo] - JSON.parse(exported).keys).empty? && (JSON.parse(exported).keys - %w[id name tokens logo dark]).empty? }
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
  check("an imported set keeps the dark values of the file") do
    moved = OpenProject::Thematiq::Store.new.custom_drafts.find { |draft| draft.name == catalogue.find("zuiddrecht").name }
    moved && catalogue.find("zuiddrecht").dark? && moved.token_set.dark_tokens == catalogue.find("zuiddrecht").dark_tokens
  end

  throwaway = session_for("admin", ADMIN_PASSWORD)
  throwaway.post "/admin/thematiq/import", params: { file: upload.call(JSON.generate(good)) }
  check("an import without a CSRF token is refused") { throwaway.response.status == 422 }

  admin.get "/admin/thematiq/export", params: { id: "custom" }
  check("the custom design system exports and imports back to the same tokens") do
    OpenProject::Thematiq::Transfer.import(admin.response.body).tokens == OpenProject::Thematiq::Store.new.custom_set.tokens
  end

  # 5b. Figma token sets
  as_member.get "/admin/thematiq/figma", params: { id: default.id }
  check("a non-admin cannot open the Figma page") { as_member.response.status == 403 }
  as_member.get "/admin/thematiq/figma/download", params: { id: default.id, file_format: "dtcg" }
  check("a non-admin cannot download for Figma") { as_member.response.status == 403 }

  admin.get "/admin/thematiq/figma", params: { id: default.id }
  check("the Figma page offers the three formats and the upload") do
    admin.response.status == 200 && OpenProject::Thematiq::Figma::FORMATS.all? { |format| admin.response.body.include?("file_format=#{format}") } &&
      admin.response.body.include?('id="thematiq-figma-form"')
  end
  figma_files = OpenProject::Thematiq::Figma::FORMATS.to_h do |format|
    admin.get "/admin/thematiq/figma/download", params: { id: default.id, file_format: format }
    check("download for Figma as #{format} sends a JSON attachment") do
      admin.response.status == 200 && admin.response.headers["Content-Disposition"].to_s.include?("attachment") &&
        admin.response.media_type == "application/json" && JSON.parse(admin.response.body).is_a?(Hash)
    end
    [format, admin.response.body]
  end
  admin.get "/admin/thematiq/figma/download", params: { id: default.id, file_format: "zip" }
  check("an unknown Figma format gives 404") { admin.response.status == 404 }
  admin.get "/admin/thematiq/figma/download", params: { id: "no-such-set", file_format: "dtcg" }
  check("download for Figma of an unknown design system gives 404") { admin.response.status == 404 }

  figma_upload = lambda do |contents|
    token = form_token(admin, "/admin/thematiq/figma", "thematiq-figma-form")
    admin.post "/admin/thematiq/figma", params: { files: contents.map { |content| upload.call(content) }, authenticity_token: token }
  end
  before = OpenProject::Thematiq::Store.new.custom_drafts.size
  ids_before = OpenProject::Thematiq::Store.new.custom_drafts.map(&:id)
  figma_files.each do |format, content|
    figma_upload.call([content])
    drafts = OpenProject::Thematiq::Store.new.custom_drafts
    check("an upload from Figma of the #{format} file shows the report and adds a design system") do
      admin.response.status == 200 && admin.response.body.include?('data-test-selector="thematiq-figma-report"') &&
        admin.response.body.include?("Every token in the file was used.")
    end
    check("the #{format} file comes back with the values it left with") { drafts.any? { |draft| draft.token_set.tokens == default.tokens } }
  end
  check("each upload from Figma added one custom design system") { OpenProject::Thematiq::Store.new.custom_drafts.size == before + 3 }
  check("an upload from Figma applies nothing") { OpenProject::Thematiq::Store.new.active_custom_id.nil? }

  hostile_file = { "nldesign" => { "color" => { "primary" => { "$value" => "red; } body { display:none", "$type" => "color" },
                                                 "text" => { "$value" => "#111111", "$type" => "color" },
                                                 "<script>alert(1)</script>" => { "$value" => "#fff", "$type" => "color" } } } }.to_json
  figma_upload.call([hostile_file])
  check("a hostile value in a Figma file is skipped and named, escaped") do
    body = admin.response.body
    admin.response.status == 200 && body.include?("Not a colour, a length or a font stack the plugin accepts") &&
      !body.include?("<script>alert(1)</script>") && body.include?("&lt;script&gt;alert(1)&lt;/script&gt;") && !body.include?("red; }")
  end
  figma_upload.call(["{ not json"])
  admin.follow_redirect!
  check("a Figma file that is not JSON is refused with a message") { admin.response.body.include?("could not be read as JSON") }
  figma_upload.call([{ "a" => { "$value" => "#fff", "$type" => "color" } }.to_json])
  admin.follow_redirect!
  check("a Figma file with nothing usable is refused") { admin.response.body.include?("no token this plugin can use") }
  throwaway = ActionDispatch::Integration::Session.new(Rails.application)
  throwaway.host! HOST
  throwaway.post "/admin/thematiq/figma", params: { files: [upload.call(figma_files["dtcg"])] }
  check("an upload from Figma without a session is refused") { [302, 401, 403, 422].include?(throwaway.response.status) }
  (OpenProject::Thematiq::Store.new.custom_drafts.map(&:id) - ids_before).each { |id| OpenProject::Thematiq::Store.new.delete_custom(id) }

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
   "/thematiq/files/%2e%2e%2f%2e%2e%2fetc%2fpasswd", "/thematiq/files/#{Thematiq::Upload.find_by(token: replaced.token).id}", "/thematiq/files/",
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

  # 8. Uploads through the admin page, for a custom design system that is saved and active.
  admin = session_for("admin", ADMIN_PASSWORD)
  OpenProject::Thematiq::Store.new.custom_drafts.each { |draft| OpenProject::Thematiq::Store.new.delete_custom(draft.id) }
  token = form_token(admin, "/admin/thematiq/custom", "thematiq-editor-form")
  admin.get "/admin/thematiq/custom"
  check("a design system that is not saved yet offers no upload") do
    admin.response.body.include?("Save this design system first") && !admin.response.body.include?('id="thematiq-file-logo-form"')
  end
  admin.post "/admin/thematiq/custom", params: { name: "Upload check", based_on: default.id, save: "1",
                                                 tokens: { "font-family" => "'Check Sans', sans-serif" }, authenticity_token: token }
  set_id = OpenProject::Thematiq::Store.new.active_custom_id
  editor = "/admin/thematiq/custom?id=#{set_id}"
  check("the custom design system for the upload checks is saved and active") { set_id.present? }

  binary = lambda do |content, name|
    file = Tempfile.new(["thematiq-upload", File.extname(name)])
    file.binmode
    file.write(content)
    file.close
    # The content type is a lie on purpose: the plugin must not look at it.
    Rack::Test::UploadedFile.new(file.path, "text/plain", true, original_filename: name)
  end
  send_file = lambda do |kind, content, name, extra = {}|
    form = "thematiq-file-#{kind.tr('_', '-')}-form"
    admin.post "/admin/thematiq/custom/files", params: { id: set_id, kind:, upload: "1", file: binary.call(content, name),
                                                         authenticity_token: form_token(admin, editor, form) }.merge(extra)
    admin.follow_redirect!
    admin.response.body
  end
  records = -> { Thematiq::Upload.records_for(set_id) }
  of_kind = ->(kind) { records.call.reverse.find { |record| record.kind == kind } }

  admin.get editor
  body = admin.response.body
  check("the editor of a saved design system has an upload form per kind") do
    %w[logo logo-inverse logo-mobile favicon touch-icon font].all? { |kind| body.include?(%(id="thematiq-file-#{kind}-form")) }
  end
  check("each field states its limits") { body.include?("At most 512 KB") && body.include?("2000 by 1000 px") && body.include?("12 files per design system") }
  check("each upload form has a named upload button") { body.scan(/<button[^>]*name="upload"/).size == 6 }

  body = send_file.call("logo", UploadSamples.svg("clean-logo"), "logo.txt")
  logo = of_kind.call("logo")
  check("an SVG logo is uploaded, whatever its name and declared type") { logo&.format == "svg" && body.include?("The logo is uploaded and in use.") }
  check("the editor shows a preview of it") { body.include?(%(<img src="#{logo.url}")) }
  check("the editor offers replace and remove for it") do
    body.include?("Replace") && body.match?(/<button[^>]*name="remove"[^>]*value="#{logo.token}"|<button[^>]*value="#{logo.token}"[^>]*name="remove"/)
  end
  check("the top bar's logo rule points at the upload, on the bar and on the light high contrast bar") do
    admin.response.body.include?(%(.op-app-header .op-logo .op-logo--link:not(.op-logo--link_high_contrast) { background-image: url("#{logo.url}"); })) &&
      admin.response.body.include?(%(.op-app-header .op-logo .op-logo--link.op-logo--link_high_contrast { background-image: url("#{logo.url}"); }))
  end
  anonymous = session_for
  anonymous.get "/login"
  check("the sign in page carries the uploaded logo") { anonymous.response.body.include?(logo.url) }
  anonymous.get logo.url
  check("the uploaded logo is served without a sign in") { anonymous.response.status == 200 && anonymous.response.body.include?("<svg") }

  body = send_file.call("logo", UploadSamples.svg("hostile-script"), "logo.svg")
  replaced = of_kind.call("logo")
  check("an upload replaces the file of that kind and says parts were left out") do
    replaced.token != logo.token && records.call.count { |record| record.kind == "logo" } == 1 && body.include?("left out")
  end
  anonymous.get replaced.url
  check("the stored hostile SVG has no script") { anonymous.response.status == 200 && !anonymous.response.body.include?("script") }
  anonymous.get logo.url
  check("the replaced file's address is gone") { anonymous.response.status == 404 }

  send_file.call("logo_inverse", UploadSamples.png(300, 80), "inverse.png")
  check("the logo for the coloured bar wins in the top bar") do
    admin.get "/admin/thematiq"
    admin.response.body.include?(%(.op-logo--link:not(.op-logo--link_high_contrast) { background-image: url("#{of_kind.call('logo_inverse').url}"); }))
  end
  send_file.call("logo_mobile", UploadSamples.webp(64, 64), "mobile.webp")
  check("the mobile logo gets its rule on the element narrow screens show") do
    admin.get "/admin/thematiq"
    admin.response.body.include?(%(.op-app-header .op-logo--icon.op-logo--link { background-image: url("#{of_kind.call('logo_mobile').url}"); }))
  end

  send_file.call("favicon", UploadSamples.ico(32), "favicon.ico")
  send_file.call("touch_icon", UploadSamples.png(180, 180), "touch.png")
  favicon = of_kind.call("favicon")
  touch = of_kind.call("touch_icon")
  anonymous.get "/login"
  page = anonymous.response.body
  check("the page head links the uploaded favicon, after OpenProject's own") do
    links = page.scan(/<link[^>]*rel="icon"[^>]*>/)
    favicon && links.size >= 2 && links.last.include?(%(href="#{favicon.url}")) && links.last.include?('type="image/x-icon"') &&
      links.last.include?('sizes="32x32"')
  end
  check("the page head links the uploaded touch icon") { touch && page.include?(%(href="#{touch.url}")) && page.include?('rel="apple-touch-icon"') }
  admin.get "/this-page-does-not-exist-#{SecureRandom.hex(4)}"
  check("an error page links the uploaded icons and logo as well") do
    admin.response.status == 404 && admin.response.body.include?(favicon.url) && admin.response.body.include?(of_kind.call("logo_inverse").url)
  end

  body = send_file.call("font", UploadSamples.woff2, "check.woff2", { font_family: "Check Sans", font_weight: "400", font_style: "normal" })
  face = of_kind.call("font")
  check("a font is uploaded with its family, weight and style") { face&.face&.family == "Check Sans" && body.include?("The font is uploaded and in use.") }
  anonymous.get "/login"
  check("the page loads the uploaded font with font-display swap") do
    anonymous.response.body.include?("@font-face { font-family: 'Check Sans'; font-style: normal; font-weight: 400; font-display: swap; src: url(#{face.url}) format('woff2'); }")
  end
  send_file.call("font", UploadSamples.ttf, "check-bold.ttf", { font_family: "Check Sans", font_weight: "700", font_style: "normal" })
  send_file.call("font", UploadSamples.woff, "check.woff", { font_family: "Check Sans", font_weight: "400", font_style: "normal" })
  check("a font with the same family, weight and style replaces, another weight is added") do
    records.call.select { |record| record.kind == "font" }.map { |record| [record.format, record.font_weight] }.sort == [%w[ttf 700], %w[woff 400]]
  end
  admin.get "/admin/thematiq"
  check("the picker says the font is an uploaded file") { admin.response.body.include?("The font Check Sans is an uploaded file of this design system.") }

  before = records.call.map(&:token).sort
  { "a script with a picture's name" => ["logo", "<script>alert(1)</script>", "logo.png", "does not know this kind of file"],
    "a file that starts like a PNG and is not one" => ["logo", "\x89PNG\r\n\x1A\n<script>alert(1)</script>".b, "logo.png", "damaged"],
    "a PNG with something after its end" => ["logo", UploadSamples.png + "<script>alert(1)</script>", "logo.png", "damaged"],
    "a picture that declares 60,000 pixels a side" => ["logo", UploadSamples.png(60_000, 60_000), "logo.png", "too large"],
    "a file over the size cap" => ["favicon", UploadSamples.png(32, 32) + ("x" * 200_000), "favicon.png", "too large"],
    "a font in the logo field" => ["logo", UploadSamples.woff2, "logo.svg", "does not fit here"],
    "an SVG in the touch icon field" => ["touch_icon", UploadSamples.svg("clean-logo"), "touch.png", "does not fit here"],
    "an SVG that declares entities" => ["logo", UploadSamples.svg("hostile-entity-bomb"), "logo.svg", "declares entities"],
    "an SVG that reads a local file" => ["logo", UploadSamples.svg("hostile-external-entity"), "logo.svg", "declares entities"],
    "an SVG that draws itself a million times" => ["logo", UploadSamples.svg("hostile-use-bomb"), "logo.svg", "too complex"],
    "an HTML page" => ["logo", UploadSamples.svg("not-svg-html"), "logo.svg", "does not know this kind of file"],
    "an empty file" => ["logo", "", "logo.svg", "Choose a file first"] }.each do |label, (kind, content, name, message)|
    body = send_file.call(kind, content, name)
    check("#{label} is refused in plain words") { body.include?(message) }
    check("after #{label} the stored files are unchanged") { records.call.map(&:token).sort == before }
    check("after #{label} nothing hostile is on the page") { !body.include?("<script>alert(1)</script>") }
  end
  body = send_file.call("font", UploadSamples.woff2, "x.woff2", { font_family: "x'; } body { display:none", font_weight: "400", font_style: "normal" })
  check("a hostile font name is refused") { body.include?("Give the font a family name") && records.call.map(&:token).sort == before }
  body = send_file.call("logo", UploadSamples.png, "../../../config/database.yml")
  check("a file name with a path in it is only ever a label") do
    of_kind.call("logo").format == "png" && !body.include?("adapter:") && of_kind.call("logo").file_name == "logo.png"
  end
  admin.post "/admin/thematiq/custom/files", params: { id: set_id, kind: "export_logo", upload: "1", file: binary.call(UploadSamples.png, "x.png"),
                                                       authenticity_token: form_token(admin, editor, "thematiq-file-logo-form") }
  admin.follow_redirect!
  check("a kind the plugin does not have is refused") { admin.response.body.include?("does not know that kind of file") }
  admin.post "/admin/thematiq/custom/files", params: { id: "custom-9998", kind: "logo", upload: "1", file: binary.call(UploadSamples.png, "x.png"),
                                                       authenticity_token: form_token(admin, editor, "thematiq-file-logo-form") }
  check("an upload for a design system that does not exist gives 404") { admin.response.status == 404 && Thematiq::Upload.records_for("custom-9998").empty? }
  admin.post "/admin/thematiq/custom/files", params: { id: "../../etc", kind: "logo", upload: "1", file: binary.call(UploadSamples.png, "x.png"),
                                                       authenticity_token: form_token(admin, editor, "thematiq-file-logo-form") }
  check("an upload for an id that is a path gives 404") { admin.response.status == 404 }

  count = Thematiq::Upload.count
  as_member = session_for(MEMBER_LOGIN, MEMBER_PASSWORD)
  as_member.post "/admin/thematiq/custom/files", params: { id: set_id, kind: "logo", upload: "1", file: binary.call(UploadSamples.png, "x.png") }
  check("a non-admin cannot upload") { [403, 422].include?(as_member.response.status) && Thematiq::Upload.count == count }
  throwaway = session_for("admin", ADMIN_PASSWORD)
  throwaway.post "/admin/thematiq/custom/files", params: { id: set_id, kind: "logo", upload: "1", file: binary.call(UploadSamples.png, "x.png") }
  check("an upload without a CSRF token is refused") { throwaway.response.status == 422 && Thematiq::Upload.count == count }
  session_for.post "/admin/thematiq/custom/files", params: { id: set_id, kind: "logo", upload: "1", file: binary.call(UploadSamples.png, "x.png") }
  check("an anonymous upload stores nothing") { Thematiq::Upload.count == count }

  admin = session_for("admin", ADMIN_PASSWORD)
  admin.get "/admin/thematiq/export", params: { id: set_id }
  exported_with_files = admin.response.body
  check("the export names the kinds of file it leaves behind and holds none") do
    note = JSON.parse(exported_with_files)["uploads"]
    note["included"] == false && note["kinds"].sort == %w[favicon font logo logo_inverse logo_mobile touch_icon] &&
      !exported_with_files.include?(of_kind.call("logo").token) && exported_with_files.bytesize < 8_000
  end
  body = import.call(exported_with_files)
  check("an import of that file says which files to upload again") { body.include?("Its uploaded files did not come along") }
  imported_id = (OpenProject::Thematiq::Store.new.custom_drafts.map(&:id) - [set_id]).first
  check("the imported design system has no files") { imported_id && Thematiq::Upload.records_for(imported_id).empty? }

  gone = of_kind.call("favicon")
  admin.post "/admin/thematiq/custom/files", params: { id: set_id, kind: "favicon", remove: gone.token,
                                                       authenticity_token: form_token(admin, editor, "thematiq-file-favicon-form") }
  admin.follow_redirect!
  check("remove takes the file away and says so") { of_kind.call("favicon").nil? && admin.response.body.include?("The file is removed.") }
  anonymous.get gone.url
  check("the removed file's address answers 404") { anonymous.response.status == 404 }
  anonymous.get "/login"
  check("the page head no longer links the favicon of the plugin") { !anonymous.response.body.include?(gone.url) }
  admin.post "/admin/thematiq/custom/files", params: { id: imported_id, kind: "logo", remove: of_kind.call("logo").token,
                                                       authenticity_token: form_token(admin, editor, "thematiq-file-logo-form") }
  check("a file cannot be removed through another design system") { !of_kind.call("logo").nil? }

  kept = records.call.map(&:token)
  admin.post "/admin/thematiq/custom", params: { id: set_id, delete: "1", authenticity_token: form_token(admin, editor, "thematiq-editor-form") }
  check("deleting the design system removes its files") { kept.size >= 5 && Thematiq::Upload.where(token: kept).none? }
  anonymous.get "/thematiq/files/#{kept.first}"
  check("and their addresses answer 404") { anonymous.response.status == 404 }

  # 9. At the limit a new custom design system is refused. It once fell back to the id "custom" and overwrote that one.
  full = OpenProject::Thematiq::Store.new
  while (free_id = full.next_custom_id)
    full.save_custom(OpenProject::Thematiq::CustomDraft.new(base: default, name: "Filler #{free_id}", overrides: { "primary" => "#123456" }, id: free_id))
  end
  first_before = OpenProject::Thematiq::Store.new.custom_draft("custom")&.definition
  admin.get "/admin/thematiq/custom", params: { from: default.id }
  check("at the limit the editor does not open a new one") { admin.response.status == 302 }
  admin.follow_redirect! if admin.response.redirect?
  check("and says why") { admin.response.body.include?("which is the most the plugin keeps") }
  token = form_token(admin, "/admin/thematiq/custom?id=custom", "thematiq-editor-form")
  admin.post "/admin/thematiq/custom", params: { name: "One too many", based_on: default.id, save: "1", tokens: { "primary" => "#ff0000" },
                                                 authenticity_token: token }
  check("at the limit saving a new one is refused") { admin.response.status == 302 }
  check("and no stored design system is overwritten") do
    store = OpenProject::Thematiq::Store.new
    store.custom_drafts.size == 50 && store.custom_drafts.none? { |draft| draft.name == "One too many" } &&
      store.custom_draft("custom")&.definition == first_before
  end
  admin.post "/admin/thematiq/custom", params: { id: "custom", name: "Filler edited", based_on: default.id, save: "1",
                                                 tokens: { "primary" => "#123456" }, authenticity_token: token }
  check("at the limit a stored one can still be edited") { OpenProject::Thematiq::Store.new.custom_draft("custom")&.name == "Filler edited" }
ensure
  [set_id, imported_id, "custom-9998", "custom-9999"].compact.each { |id| Thematiq::Upload.remove_set(id) } if defined?(Thematiq::Upload)
  Setting.plugin_openproject_thematiq = saved_settings
  member.destroy
end

puts "#{$checks} checks, #{$failures.size} failures"
exit($failures.empty? ? 0 : 1)
