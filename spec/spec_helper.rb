# frozen_string_literal: true

require "bundler/setup"

require "canon"
require "simplecov"

SimpleCov.start do
  add_filter "/spec/"
end

require_relative "../lib/iev"

# CLI dependencies — needed for acceptance tests that exercise the CLI
require "benchmark"
require "creek"
require "glossarist"
require "nokogiri"
require "relaton"
require "relaton/bib"
require "sequel"
require "thor"
require_relative "../lib/iev/cli"

Dir["./spec/support/**/*.rb"].each { |file| require file }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.include Iev::ConsoleHelper
  config.include Iev::FixtureHelper

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
