# frozen_string_literal: true

module OpenProject
  module Thematiq
    # Where the shared appearance link may send a person back to: a path on this OpenProject, or an address under the
    # Nextcloud address the administrator gave. Everything else is nil.
    #
    # Only printable URL characters pass. Browsers drop tabs and line breaks from an address and read a backslash as
    # a slash, so "/\t/evil.example" or "/\\evil.example" would become the other host "//evil.example".
    module ReturnTo
      MAX_LENGTH = 500
      URL_CHARACTERS = %r{\A[A-Za-z0-9\-._~!$&'()*+,;=:@/?#%\[\]]*\z}

      module_function

      # A path that starts with one slash and names no other host, or nil.
      def path(target)
        target = target.to_s
        return nil unless target.length <= MAX_LENGTH && URL_CHARACTERS.match?(target)
        return nil unless target.start_with?("/") && !target.start_with?("//")

        target
      end

      # An address under the Nextcloud address (its scheme, host and path, then a slash), or nil.
      def nextcloud(target, nextcloud_url)
        target = target.to_s
        return nil if nextcloud_url.to_s.empty?
        return nil unless target.length <= MAX_LENGTH && URL_CHARACTERS.match?(target)

        target.start_with?("#{nextcloud_url.to_s.chomp('/')}/") ? target : nil
      end
    end
  end
end
