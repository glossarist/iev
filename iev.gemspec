lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "iev/version"

Gem::Specification.new do |spec|
  spec.name          = "iev"
  spec.version       = Iev::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com"]

  spec.summary       = %q{IEV: Fetch and encode IEV term from Electropedia}
  spec.description   = %q{IEV: Fetch and encode IEV term from Electropedia}
  spec.homepage      = "https://github.com/metanorma/iev"
  spec.license       = "BSD-2-Clause"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.add_development_dependency "bundler", "~> 2.0.1"
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency 'simplecov'

  spec.add_dependency 'nokogiri'
end
