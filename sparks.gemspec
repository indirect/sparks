# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "sparks/version"

Gem::Specification.new do |s|
  s.name        = "sparks"
  s.version     = Sparks::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["André Arko", "James Cox"]
  s.email       = ["andre@arko.net"]
  s.homepage    = "http://github.com/indirect/sparks"
  s.summary     = %q{A tiny Campfire client API}
  s.description = %q{A tiny Campfire client API that only uses the standard library}

  s.rubyforge_project = "sparks"
  s.add_dependency "json"
  s.add_development_dependency "bundler", "~>1.0"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
