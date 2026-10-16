# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Shell
      # The Nextcloud column of the app switcher.
      #
      # THIS LIST IS FIXED. It does not ask Nextcloud which apps are installed or which ones
      # the user may open. A later version reads the list from Nextcloud's navigation API.
      #
      # The address comes from Shell.nextcloud_url. Without one there is no column.
      module NextcloudApps
        App = Struct.new(:key, :path, :icon)
        SLASH = "/".ord

        # The icon is the path data of the outline icon in the OpHeader design (24 px grid).
        APPS = [
          App.new(:files, "/apps/files/",
                  "M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"),
          App.new(:mail, "/apps/mail/",
                  "M4 4h16a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2zM22 6l-10 7L2 6"),
          App.new(:calendar, "/apps/calendar/",
                  "M8 2v4M16 2v4M3 10h18M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z"),
          App.new(:tasks, "/apps/tasks/",
                  "M9 11l3 3L22 4M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"),
          App.new(:talk, "/apps/spreed/",
                  "M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"),
          App.new(:contacts, "/apps/contacts/",
                  "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8" \
                  "M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75")
        ].freeze

        # The address without a trailing slash, or nil when it is not an http or https address.
        # The value ends up in a link, so nothing else gets through.
        def self.normalize(value)
          url = value.to_s.strip
          length = url.bytesize
          length -= 1 while length.positive? && url.getbyte(length - 1) == SLASH
          url = url.byteslice(0, length)
          url.match?(%r{\Ahttps?://[^\s"'<>]+\z}i) ? url : nil
        end

        def self.url_for(app, base)
          "#{base}#{app.path}"
        end
      end
    end
  end
end
