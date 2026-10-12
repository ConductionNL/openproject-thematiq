module OpenProject
  module TokenTheme
    require "open_project/token_theme/engine"

    CSS_PATH = File.expand_path("../../config/theme.css", __dir__)

    # Read per request with an mtime cache, so the stylesheet can be swapped without a restart.
    def self.css
      mtime = File.mtime(CSS_PATH)
      if @mtime != mtime
        @css = File.read(CSS_PATH)
        @mtime = mtime
      end
      @css
    end
  end
end
