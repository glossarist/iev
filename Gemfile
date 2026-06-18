# frozen_string_literal: true

source "https://rubygems.org"

# Use local glossarist-ruby when available for development.
# Otherwise falls back to released gem (requires >= 2.8.15 for
# BibliographyData, Figure/NonVerbRep, and ConceptEnricher support).
if File.directory?(File.expand_path("../glossarist-ruby", __dir__))
  gem "glossarist", path: "../glossarist-ruby"
else
  gem "glossarist", ">= 2.8.15"
end

gem "benchmark"
gem "canon"
gem "openssl"
gem "rake"
gem "rspec"
gem "rubocop"
gem "rubocop-performance"
gem "rubocop-rake"
gem "rubocop-rspec"
gem "simplecov"

gemspec
