# frozen_string_literal: true

module Thematiq
  # Serves the uploaded files of the design systems: logos, icons and fonts. Nothing else.
  #
  # Anyone may ask, signed in or not: the sign in page and the browser tab need these files.
  # So this is a bare controller. It reads no session, sets no cookie and runs none of OpenProject's filters.
  #
  # How it stays closed:
  #   - The route only matches 64 hex characters. A dot, a slash or a percent sign never gets here.
  #   - That text is looked up as a value in one column of the plugin's own table. It is never part of a path,
  #     and no file on disk is opened.
  #   - A row that is not one of the six kinds, or whose type does not fit its kind, is not served.
  #   - The content type is the one decided at upload from the content, with "nosniff" and a content security
  #     policy that allows no script. See OpenProject::Thematiq::Uploads::Response.
  # Only an administrator can put a file there, through the admin page, after the content checks.
  class FilesController < ActionController::Metal
    Uploads = OpenProject::Thematiq::Uploads

    def show
      # The router also matches the id with a slash after it. One file has one address, so that is refused here.
      record = request.original_fullpath.to_s.split("?").first.to_s.end_with?("/#{params[:token]}") ? Thematiq::Upload.find_record(params[:token].to_s) : nil
      return refuse(404) unless record

      Uploads::Response.headers(record).each { |name, value| headers[name] = value }
      if Uploads::Response.fresh?(record, request.headers["If-None-Match"])
        self.status = 304
        self.response_body = ""
        return
      end

      bytes = Thematiq::Upload.bytes_for(record.token)
      return refuse(404) unless bytes.is_a?(String) && bytes.bytesize == record.byte_size

      headers["Content-Length"] = bytes.bytesize.to_s
      self.status = 200
      self.response_body = request.head? ? "" : bytes
    rescue ActiveRecord::ActiveRecordError
      refuse(503)
    end

    private

    def refuse(code)
      headers.clear
      headers["Content-Type"] = "text/plain; charset=utf-8"
      headers["Cache-Control"] = "no-store"
      headers["X-Content-Type-Options"] = "nosniff"
      self.status = code
      self.response_body = code == 404 ? "Not found\n" : "Not available\n"
    end
  end
end
