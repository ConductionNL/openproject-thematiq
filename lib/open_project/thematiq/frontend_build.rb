# frozen_string_literal: true

require "digest"
require "json"
require "open_project/thematiq/version"

module OpenProject
  module Thematiq
    # Whether this image runs OpenProject's frontend rebuilt with the plugin's Angular module (the frontend target
    # of docker/Dockerfile), read from the stamp that target writes. The default image has no stamp.
    module FrontendBuild
      STAMP = "frontend-build.json"
      MODULE_DIR = "frontend/module"
      PLUGIN_ROOT = File.expand_path("../../..", __dir__)

      Status = Struct.new(:state, :stamp, keyword_init: true) do
        # :absent  the default image: OpenProject's own prebuilt frontend, without the plugin's module
        # :current the plugin's module is in the bundle and was built from the sources on disk
        # :stale   a bundle with the plugin's module, built from other sources than the ones on disk
        def linked? = state != :absent
        def current? = state == :current
      end

      module_function

      # A digest over the module's sources, so a plugin updated without a rebuild shows as stale.
      def module_digest(dir)
        digest = Digest::SHA256.new
        Dir.glob("**/*", base: dir).sort.each do |relative|
          path = File.join(dir, relative)
          next unless File.file?(path)

          digest << relative << "\0" << File.binread(path) << "\0"
        end
        digest.hexdigest
      end

      def status(root: PLUGIN_ROOT)
        stamp = read_stamp(File.join(root, STAMP))
        return Status.new(state: :absent, stamp: nil) unless stamp

        same = stamp["plugin_version"] == VERSION && stamp["module_digest"] == module_digest(File.join(root, MODULE_DIR))
        Status.new(state: same ? :current : :stale, stamp:)
      end

      # The status of this process's image. The bundle and the module on disk do not change while it runs.
      def cached_status
        @cached_status ||= status
      end

      def read_stamp(path)
        return nil unless File.file?(path)

        document = JSON.parse(File.read(path))
        document.is_a?(Hash) && document["module_digest"].is_a?(String) ? document : nil
      rescue JSON::ParserError, SystemCallError
        nil
      end
    end
  end
end
