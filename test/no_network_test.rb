# frozen_string_literal: true

require "test_helper"

# The plugin is standalone. Nothing in it may open a connection.
class NoNetworkTest < Minitest::Test
  FILES = Dir[File.expand_path("../{lib,app,config}/**/*.{rb,erb}", __dir__)].sort
  NETWORK = %r{net/http|Net::HTTP|open-uri|URI\.open|TCPSocket|TCPServer|UDPSocket|HTTPX|httpx|Faraday|RestClient|Typhoeus|Excon|perform_later|ApplicationJob}

  def test_there_are_files_to_check
    assert_operator FILES.size, :>, 5
  end

  def test_no_file_reaches_for_the_network_or_a_background_job
    FILES.each { |file| refute_match NETWORK, File.read(file), file }
  end

  def test_the_loaded_token_code_did_not_pull_in_an_http_library
    refute defined?(Net::HTTP), "net/http is loaded"
  end
end
