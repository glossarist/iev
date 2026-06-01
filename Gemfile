# frozen_string_literal: true

source "https://rubygems.org"

# Tags support requires glossarist with ManagedConceptData#tags attribute.
# Use local path when available, otherwise git source (until gem release).
if File.directory?(File.expand_path("../glossarist-ruby", __dir__))
  gem "glossarist", path: "../glossarist-ruby"
  gem "lutaml-store", path: "../../lutaml/lutaml-store" if
    File.directory?(File.expand_path("../../lutaml/lutaml-store", __dir__))
else
  gem "glossarist", git: "https://github.com/glossarist/glossarist-ruby",
                    ref: "e6a12ff"
  gem "lutaml-store", git: "https://github.com/lutaml/lutaml-store",
                      ref: "3ce3f66"
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
