# frozen_string_literal: true

source "https://rubygems.org"

gem "benchmark"
gem "canon"
gem "openssl"
gem "lutaml-model", github: "lutaml/lutaml-model", ref: "main"
gem "rake"
gem "rspec"
gem "rubocop"
gem "rubocop-performance"
gem "rubocop-rake"
gem "rubocop-rspec"
gem "simplecov"

gemspec

# Override relaton gems with lutaml-model 0.8 compatible versions.
# Released 2.0.0 sub-gems have untyped lutaml-model attributes that fail with 0.8+.
# fix/lutaml-model-0.8 branches keep version 2.0.0 (compatible) + lutaml-model ~> 0.8.
# lutaml-integration branches also have typed attributes and work with relaton-bib ~> 2.0.0.
# TODO: Remove once relaton gems release versions with lutaml-model 0.8 support.
gem "relaton-bib", github: "relaton/relaton-bib", branch: "fix/lutaml-model-0.8"
gem "relaton-iso", github: "relaton/relaton-iso", branch: "fix/lutaml-model-0.8"
gem "relaton-3gpp", github: "relaton/relaton-3gpp", branch: "fix/lutaml-model-0.8"
gem "relaton-bipm", github: "relaton/relaton-bipm", branch: "fix/lutaml-model-0.8"
gem "relaton-bsi", github: "relaton/relaton-bsi", branch: "fix/lutaml-model-0.8"
gem "relaton-calconnect", github: "relaton/relaton-calconnect", branch: "lutaml-integration"
gem "relaton-ccsds", github: "relaton/relaton-ccsds", branch: "lutaml-integration"
gem "relaton-cen", github: "relaton/relaton-cen", branch: "lutaml-integration"
gem "relaton-iec", github: "relaton/relaton-iec", branch: "lutaml-integration"
gem "relaton-itu", github: "relaton/relaton-itu", branch: "lutaml-integration"
