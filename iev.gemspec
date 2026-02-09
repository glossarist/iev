# frozen_string_literal: true

require_relative "lib/iev/version"

Gem::Specification.new do |spec|
  spec.name = "iev"
  spec.version = Iev::VERSION
  spec.authors = ["Ribose Inc."]
  spec.email = ["open.source@ribose.com"]

  spec.summary = "Glossarist toolkit for working with IEV terms from Electropedia"
  spec.description = "Glossarist toolkit for working with IEV terms from Electropedia"
  spec.homepage = "https://github.com/glossarist/iev"
  spec.license = "BSD-2-Clause"

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = Gem::Requirement.new(">= 3.1.0")

  spec.add_dependency "creek", "~> 2.6"
  spec.add_dependency "glossarist", ">= 2.3.0"
  spec.add_dependency "mechanize", "~> 2.10"
  spec.add_dependency "nokogiri", "~> 1.17"
  spec.add_dependency "plurimath"
  spec.add_dependency "relaton", "~> 1.18"
  spec.add_dependency "sequel", "~> 5.40"
  spec.add_dependency "sqlite3", "~> 1.7.0"
  spec.add_dependency "thor", "~> 1.0"
  spec.add_dependency "unitsml"
end
