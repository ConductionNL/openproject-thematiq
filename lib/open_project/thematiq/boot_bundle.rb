# frozen_string_literal: true

require "digest"

module OpenProject
  module Thematiq
    # A branding package that applies itself (app-branding-package): THEMATIQ_BUNDLE_FILE names a configuration file
    # (see Bundle), and when OpenProject starts the plugin makes it the setup. Only when the file changed since it was
    # last applied, so an administrator's later changes stay until the file changes again. Never fails a start.
    module BootBundle
      FILE_KEY = "THEMATIQ_BUNDLE_FILE"
      LOCK = 0x7468656d # "them": one process applies at a time

      Outcome = Struct.new(:status, :detail, keyword_init: true)

      module_function

      # status: :off, :not_ready, :missing, :unchanged, :refused or :applied.
      # apply: a callable that takes a checked bundle and the file's digest and makes it the setup.
      def run(env:, store:, ready:, read:, apply:)
        path = env[FILE_KEY].to_s.strip
        return Outcome.new(status: :off) if path.empty?
        return Outcome.new(status: :not_ready) unless ready.call
        return Outcome.new(status: :missing, detail: path) unless File.file?(path)

        text = File.read(path, Bundle::MAX_BYTES + 1)
        digest = Digest::SHA256.hexdigest(text.to_s)
        return Outcome.new(status: :unchanged, detail: digest) if store.bundle_file_digest == digest

        checked = read.call(text)
        apply.call(checked, digest)
        Outcome.new(status: :applied, detail: File.basename(path))
      rescue Bundle::Refused => e
        Outcome.new(status: :refused, detail: e.code)
      end
    end
  end
end
