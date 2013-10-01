lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "sparks/version"

Gem::Specification.new do |gem|
  gem.name        = "sparks"
  gem.version     = Sparks::VERSION
  gem.summary     = %q{A tiny Campfire client API}
  gem.description = %q{Yet another Campfire client. Because oh my god so many dependencies.}
  gem.authors     = ["André Arko"]
  gem.email       = ["andre@arko.net"]
  gem.homepage    = "http://github.com/indirect/sparks"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}) { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "yajl-ruby", "~> 1.1"
  gem.add_dependency "http", "~> 0.5"

  gem.add_development_dependency "rake", "~> 10.0"
  gem.add_development_dependency "bundler", "~> 1.2"
end
