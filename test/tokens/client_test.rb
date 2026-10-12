# frozen_string_literal: true

require "test_helper"
require "socket"

class ClientTest < Minitest::Test
  Client = OpenProject::Thematiq::Tokens::Client

  # A one-shot HTTP server on a free local port. The block gets the request text and returns the raw response.
  def serve
    server = TCPServer.new("127.0.0.1", 0)
    requests = []
    thread = Thread.new do
      loop do
        socket = server.accept
        request = +""
        while (line = socket.gets) && line != "\r\n"
          request << line
        end
        requests << request
        response = yield(request)
        socket.write(response) if response
        socket.close
      rescue IOError, Errno::EPIPE, Errno::ECONNRESET
        break
      end
    end
    ["http://127.0.0.1:#{server.addr[1]}", requests]
  ensure
    @servers = (@servers || []) << [server, thread]
  end

  def teardown
    (@servers || []).each do |server, thread|
      server.close
      thread.kill
    end
  end

  def http(status, body, type: "application/json")
    "HTTP/1.1 #{status}\r\nContent-Type: #{type}\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
  end

  def test_builds_the_endpoint
    assert_equal "https://cloud.example.org/apps/thematiq/api/shell-tokens", Client.endpoint_for("https://cloud.example.org/").to_s
    assert_equal "http://localhost:8080/index.php/apps/thematiq/api/shell-tokens", Client.endpoint_for("http://localhost:8080/index.php").to_s
    ["", "cloud.example.org", "ftp://x", "https://u:p@x/", "https://x/?a=1", "javascript:alert(1)", nil].each do |value|
      assert_nil Client.endpoint_for(value), "accepted base url #{value.inspect}"
    end
  end

  def test_reads_json
    base, requests = serve { http("200 OK", '{"version":1}') }
    result = Client.new.fetch(base)

    assert result.ok?
    assert_equal({ "version" => 1 }, result.payload)
    assert_match %r{\AGET /apps/thematiq/api/shell-tokens HTTP/1.1}, requests.first
    refute_match(/If-None-Match/i, requests.first)
  end

  def test_sends_if_none_match_and_understands_not_modified
    base, requests = serve { "HTTP/1.1 304 Not Modified\r\nConnection: close\r\n\r\n" }
    result = Client.new.fetch(base, known_revision: "r42")

    assert result.not_modified?
    assert_match(/^If-None-Match: "r42"\r$/i, requests.first)
  end

  def test_never_puts_an_unsafe_revision_in_a_header
    base, requests = serve { http("200 OK", "{}") }
    Client.new.fetch(base, known_revision: "r1\r\nX-Injected: 1")
    Client.new.fetch(base, known_revision: 'r"1')

    requests.each { |request| refute_match(/If-None-Match|X-Injected/i, request) }
  end

  def test_reports_http_errors
    base, = serve { http("500 Internal Server Error", "boom") }
    result = Client.new.fetch(base)

    assert result.error?
    assert_equal "http_status", result.error
    assert_equal "500", result.detail
  end

  def test_does_not_follow_redirects
    base, = serve { "HTTP/1.1 302 Found\r\nLocation: http://169.254.169.254/\r\nContent-Length: 0\r\nConnection: close\r\n\r\n" }
    result = Client.new.fetch(base)

    assert_equal %w[http_status 302], [result.error, result.detail]
  end

  def test_reports_bad_json
    base, = serve { http("200 OK", "<html>login</html>", type: "text/html") }
    assert_equal "invalid_json", Client.new.fetch(base).error

    base, = serve { http("200 OK", "[1,2]") }
    assert_equal "invalid_json", Client.new.fetch(base).error
  end

  def test_refuses_a_body_over_the_limit
    base, = serve { http("200 OK", %({"x":"#{'a' * (Client::MAX_BODY_BYTES + 1)}"})) }

    assert_equal "too_large", Client.new.fetch(base).error
  end

  def test_gives_up_on_a_server_that_does_not_answer
    base, = serve { sleep 5 }
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = Client.new(open_timeout: 0.3, read_timeout: 0.3, deadline: 1).fetch(base)

    assert_equal "timeout", result.error
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 2
  end

  def test_reports_an_unreachable_host
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close

    assert_equal "unreachable", Client.new.fetch("http://127.0.0.1:#{port}").error
  end

  def test_reports_an_invalid_url
    assert_equal "invalid_url", Client.new.fetch("not a url").error
  end
end
