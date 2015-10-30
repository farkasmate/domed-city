# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dome/version'

Gem::Specification.new do |spec|
  spec.name          = "dome"
  spec.version       = Dome::VERSION
  spec.authors       = ["Ben Snape"]
  spec.email         = ["ben.snape@itv.com"]

  spec.summary       = %q{A simple Terraform API wrapper and helpers for ITV.}
  spec.homepage      = "https://github.com/ITV/dome"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"

  spec.add_dependency 'trollop'
  spec.add_dependency 'aws-profile_parser'
  spec.add_dependency 'aws-sdk'
  spec.add_dependency 'colorize'
end
