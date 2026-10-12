# frozen_string_literal: true

# A stand-in for thematiq's shell token endpoint, for development without a Nextcloud.
# Run it inside the OpenProject container:
#   docker exec -d <container> ruby /app/custom-plugins/openproject-thematiq/docker/fake-thematiq.rb
# Then set the base URL on the admin page to http://127.0.0.1:9911
#
# FAKE_THEMATIQ_PRIMARY changes the primary colour, and with it the revision.
require "json"
require "socket"
require "digest"

tokens = {
  "primary" => ENV.fetch("FAKE_THEMATIQ_PRIMARY", "#3669a5"), "primary-deep" => "#234a78", "primary-light" => "#eaf0f7",
  "action" => "#3669a5", "action-deep" => "#234a78", "link" => "#3669a5", "accent" => "#cc0000",
  "ink" => "#1b1c1d", "text" => "#3d4047", "muted" => "#5e6168", "line" => "#e4e6ea", "soft" => "#f5f6f8",
  "ground" => "#f5f6f8", "chip" => "#f0f1f3", "field" => "#c4c7cb", "radius" => "8px", "radius-lg" => "10px",
  "font-family" => "'Fira Sans', system-ui, sans-serif"
}
revision = Digest::SHA256.hexdigest(tokens.to_json)[0, 12]
body = JSON.generate("version" => 1, "id" => "canon-example", "name" => "Canon example", "revision" => revision,
                     "tokens" => tokens, "logo" => { "url" => nil, "inverse_url" => nil })

server = TCPServer.new("127.0.0.1", Integer(ENV.fetch("FAKE_THEMATIQ_PORT", "9911")))
loop do
  socket = server.accept
  request_line = socket.gets.to_s
  headers = {}
  while (line = socket.gets) && line != "\r\n"
    name, value = line.split(":", 2)
    headers[name.downcase] = value.to_s.strip
  end
  if !request_line.start_with?("GET /apps/thematiq/api/shell-tokens ")
    socket.write "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
  elsif headers["if-none-match"] == %("#{revision}")
    socket.write "HTTP/1.1 304 Not Modified\r\nETag: \"#{revision}\"\r\nConnection: close\r\n\r\n"
  else
    socket.write "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nETag: \"#{revision}\"\r\n" \
                 "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
  end
  socket.close
rescue StandardError => e
  warn e.message
end
