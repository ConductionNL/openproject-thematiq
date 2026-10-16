# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"
require "open_project/thematiq/federation"
require "open_project/thematiq/bundle"

# gov-federated-share: serve the setup to one other instance, and pull another's. Both off by default.
class FederationTest < Minitest::Test
  Federation = OpenProject::Thematiq::Federation
  Gallery = OpenProject::Thematiq::Gallery
  Bundle = OpenProject::Thematiq::Bundle
  ROOT = File.expand_path("..", __dir__)
  KEY = "k" * 43

  def store(data = {})
    OpenProject::Thematiq::Store.new(backend: MemoryBackend.new(data), env: {})
  end

  def test_both_sides_are_off_by_default
    fresh = store

    refute fresh.share_serving_enabled?
    refute fresh.share_pull_enabled?
    assert_nil fresh.share_key
    assert_raises(Gallery::Off) { Federation.fetch("https://other.example.org/thematiq/api/v1/setup", key: KEY, enabled: false, max_bytes: 10) }
    refute defined?(Net::HTTP), "no http library was loaded by a refused pull"
  end

  def test_turning_serving_on_makes_a_key_and_a_new_key_replaces_it
    s = store
    s.save_share_serving(enabled: true)
    first = s.share_key

    assert s.share_serving_enabled?
    assert Federation.valid_key?(first)
    s.save_share_serving(enabled: false)

    refute s.share_serving_enabled?
    assert_equal first, s.share_key, "turning it off keeps the key"
    s.save_share_serving(enabled: true, new_key: true)

    refute_equal first, s.share_key
  end

  def test_keys_are_compared_whole
    assert Federation.key_matches?(KEY, KEY)
    refute Federation.key_matches?("#{KEY}x", KEY)
    refute Federation.key_matches?(KEY[0..-2], KEY)
    refute Federation.key_matches?("", KEY)
    refute Federation.key_matches?(KEY, nil)
    refute Federation.key_matches?("short", "short")
  end

  def test_pulling_takes_only_an_https_address_and_a_share_key
    s = store

    refute s.save_share_pull(enabled: true, url: "http://other.example.org/setup", key: KEY)
    refute s.save_share_pull(enabled: true, url: "https://user:pw@other.example.org/setup", key: KEY)
    refute s.save_share_pull(enabled: true, url: "https://other.example.org/setup", key: "not a key")
    refute s.save_share_pull(enabled: true, url: "https://other.example.org/setup", key: "")
    refute s.save_share_pull(enabled: true, url: "", key: KEY)
    refute s.share_pull_enabled?
    assert s.save_share_pull(enabled: true, url: "https://other.example.org/setup", key: KEY)
    assert s.share_pull_enabled?
    assert s.save_share_pull(enabled: true, url: "https://other.example.org/setup", key: "")
    assert_equal KEY, s.share_pull_key, "an empty key keeps the stored one"
  end

  def test_the_share_settings_never_travel_in_a_configuration_file
    s = store
    s.save_share_serving(enabled: true)
    s.save_share_pull(enabled: true, url: "https://other.example.org/setup", key: KEY)
    file = Bundle.dump(Bundle.build(settings: s.settings_snapshot, scopes: []))

    refute_includes file, "share"
    refute_includes file, s.share_key
    refute_includes file, KEY
    s.replace_setup({})

    assert_equal KEY, s.share_pull_key, "taking a file in keeps the share settings"
    assert s.share_serving_enabled?
  end

  def test_a_pull_refuses_a_bad_key_before_it_connects
    assert_equal "key", assert_raises(Gallery::Refused) { Federation.fetch("https://other.example.org/setup", key: "x", enabled: true, max_bytes: 10) }.code
    refute defined?(Net::HTTP)
  end

  def test_the_pull_status_keeps_the_last_result
    s = store
    s.record_share_pull(error: "status_403", now: Time.at(100))

    assert_equal({ "pulled_at" => 100, "error" => "status_403" }, s.share_pull_status)
    s.record_share_pull(now: Time.at(200))

    assert_nil s.share_pull_status["error"]
  end

  def test_only_administrators_reach_the_share_page_and_the_endpoint_needs_no_session
    share = File.read(File.join(ROOT, "app/controllers/thematiq/share_controller.rb"))
    endpoint = File.read(File.join(ROOT, "app/controllers/thematiq/setup_endpoint_controller.rb"))
    routes = File.read(File.join(ROOT, "config/routes.rb"))

    assert_includes share, "before_action :require_admin"
    assert_match(/class SetupEndpointController < ActionController::Metal/, endpoint)
    assert_includes endpoint, "return answer(404) unless store.share_serving_enabled?"
    assert_includes endpoint, "Federation.key_matches?"
    assert_includes endpoint, %(headers["Cache-Control"] = "no-store")
    assert_includes routes, %(get "thematiq/api/v1/setup", to: "thematiq/setup_endpoint#show")
    refute_match(%r{(post|put|patch|delete) "thematiq/api/v1/setup"}, routes)
  end

  def test_a_pulled_file_goes_through_the_checks_of_a_file_uploaded_by_hand
    share = File.read(File.join(ROOT, "app/controllers/thematiq/share_controller.rb"))

    assert_includes share, "OpenProject::Thematiq::Bundle.read("
    assert_includes share, "max_bytes: OpenProject::Thematiq::Bundle::MAX_BYTES"
    assert_includes share, %(render "thematiq/admin/bundle_import")
    refute_includes share, "Change.apply!", "a pull never applies without the confirm"
  end

  # The client against a real https server on this machine, in a child process so this one never loads net/http.
  def test_the_client_sends_the_key_follows_no_redirect_and_stops_at_the_size_limit
    script = <<~RUBY
      require "openssl"
      require "socket"
      require "open_project/thematiq/federation"
      require "open_project/thematiq/gallery/client"
      Federation = OpenProject::Thematiq::Federation

      key = OpenSSL::PKey::RSA.new(2048)
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 1
      cert.subject = cert.issuer = OpenSSL::X509::Name.parse("/CN=localhost")
      cert.public_key = key.public_key
      cert.not_before = Time.now - 60
      cert.not_after = Time.now + 3600
      factory = OpenSSL::X509::ExtensionFactory.new(cert, cert)
      cert.add_extension(factory.create_extension("subjectAltName", "DNS:localhost"))
      cert.add_extension(factory.create_extension("basicConstraints", "CA:TRUE", true))
      cert.sign(key, OpenSSL::Digest.new("SHA256"))
      OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE.add_cert(cert)

      context = OpenSSL::SSL::SSLContext.new
      context.cert = cert
      context.key = key
      tcp = TCPServer.new("127.0.0.1", 0)
      port = tcp.addr[1]
      server = OpenSSL::SSL::SSLServer.new(tcp, context)
      seen = []
      Thread.new do
        loop do
          socket = begin
            server.accept
          rescue StandardError
            next
          end
          request = +""
          request << socket.gets.to_s until request.end_with?("\\r\\n\\r\\n")
          seen << request
          path = request[/\\AGET (\\S+)/, 1]
          body, status, extra = case path
                                when "/ok" then ['{"a":1}', "200 OK", ""]
                                when "/big" then ["x" * 5000, "200 OK", ""]
                                when "/moved" then ["", "302 Found", "Location: https://evil.example.org/setup\\r\\n"]
                                else ["", "403 Forbidden", ""]
                                end
          socket.write("HTTP/1.1 \#{status}\\r\\nContent-Length: \#{body.bytesize}\\r\\n\#{extra}Connection: close\\r\\n\\r\\n\#{body}")
          socket.close
        end
      end

      result = ->(path, max = 1000) do
        Federation.fetch("https://localhost:\#{port}\#{path}", key: "#{KEY}", enabled: true, max_bytes: max)
      rescue OpenProject::Thematiq::Gallery::Refused => e
        "refused:\#{e.code}"
      end
      puts "ok=\#{result.call('/ok')}"
      puts "key=\#{seen.last.to_s.include?("X-Thematiq-Share-Key: #{KEY}")}"
      puts "big=\#{result.call('/big')}"
      puts "moved=\#{result.call('/moved')}"
      puts "forbidden=\#{result.call('/nope')}"
      puts "requests=\#{seen.size}"
    RUBY
    out, err, status = Open3.capture3(RbConfig.ruby, "-I#{File.join(ROOT, 'lib')}", "-e", script)

    assert status.success?, err
    assert_includes out, %(ok={"a":1}), out
    assert_includes out, %(ok={"a":1})
    assert_includes out, "key=true"
    assert_includes out, "big=refused:too_large"
    assert_includes out, "moved=refused:status_302"
    assert_includes out, "forbidden=refused:status_403"
    assert_includes out, "requests=4", "the redirect was not followed"
  end
end
