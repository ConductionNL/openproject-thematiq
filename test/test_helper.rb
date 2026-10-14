# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "open_project/thematiq/tokens"
require "open_project/thematiq/variables/generator"
require "open_project/thematiq/catalogue"
require "open_project/thematiq/store"

# Stands in for OpenProject's settings.
class MemoryBackend
  attr_accessor :data

  def initialize(data = {})
    @data = data
  end

  def read = @data

  def write(data)
    @data = data
  end
end

# Values a hostile or broken thematiq could send. None of them may reach CSS.
HOSTILE_VALUES = [
  "red; } body { display:none",
  "#fff; background: url(//evil.example/x)",
  "#fff}</style><script>alert(1)</script>",
  "</style>",
  "url(javascript:alert(1))",
  "expression(alert(1))",
  "var(--header-bg-color)",
  "#fff /* comment */",
  "#fff\n} body { display: none",
  "rgb(0,0,0); color: red",
  "rgb(0 0 0) !important",
  "red !important",
  "\\72 ed",
  "#12345",
  "calc(1px + 1px)",
  "3px; } * { display: none",
  "",
  " ",
  nil,
  42,
  ["#fff"],
  { "a" => "#fff" }
].freeze
