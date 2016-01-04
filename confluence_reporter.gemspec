# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'confluence_reporter/version'

Gem::Specification.new do |spec|
  spec.name          = "confluence_reporter"
  spec.version       = ConfluenceReporter::VERSION
  spec.authors       = ["Martin Brehovsky"]
  spec.email         = ["mbrehovsky@adaptavist.com"]
  spec.summary       = "Api to publish to confluence"
  spec.description   = "Creates and updates pages in confluence"
  spec.homepage      = "https://github.com/Adaptavist/confluence_reporter"
  spec.license       = "Apache-2.0"
  spec.files = `git ls-files`.split($\)

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
end
