# frozen_string_literal: true

require "digest"
require "open_project/thematiq/tokens"
require "open_project/thematiq/contrast"

module OpenProject
  module Thematiq
    # The answers of the read endpoints, without Rails. Every value in them comes out of a token set, so it has
    # passed the validator. Nothing an administrator typed in a free field is answered, apart from a design system's name.
    module ReadApi
      VERSION = 1

      module_function

      # thematiq's shell-tokens answer, version 1: the eighteen roles and the logo. The same shape thematiq serves at
      # /apps/thematiq/api/shell-tokens, so a reader of one reads the other. logo_urls: [url, inverse_url], absolute or nil.
      def shell_tokens(token_set, logo_urls: [nil, nil])
        tokens = Tokens::TokenSet::KINDS.keys.to_h { |key| [key, token_set[key] || Tokens::Defaults::TOKENS[key]] }
        { "version" => VERSION, "id" => token_set.id, "name" => token_set.name,
          "revision" => Digest::SHA256.hexdigest(JSON.generate([token_set.id, tokens, logo_urls]))[0, 16],
          "tokens" => tokens, "logo" => { "url" => logo_urls[0], "inverse_url" => logo_urls[1] } }
      end

      # One row of the catalogue for another app's picker.
      def summary(token_set, active_id:, custom:)
        { "id" => token_set.id, "name" => token_set.name, "custom" => custom, "active" => token_set.id == active_id,
          "primary" => token_set["primary"], "dark" => token_set.dark? }
      end

      # The contrast of any two colours, as the plugin measures it. nil ratio: a colour the plugin cannot read.
      def contrast(foreground, background)
        fore = Tokens::Validator.color(foreground.to_s[0, 100])
        back = Tokens::Validator.color(background.to_s[0, 100])
        ratio = fore && back ? Contrast.ratio(fore, back) : nil
        { "foreground" => fore, "background" => back, "ratio" => ratio, "minimum" => Contrast::MINIMUM,
          "large_text_minimum" => 3.0,
          "verdict" => if ratio.nil? then "unknown" elsif ratio >= Contrast::MINIMUM then "pass" elsif ratio >= 3.0 then "large_text_only" else "fail" end }
      end
    end
  end
end
