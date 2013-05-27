# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)


Gem::Specification.new do |spec|
  spec.name          = "ruby_ddp_client"
  spec.version       = 0.1
  spec.authors       = ["Brendan Ryan"]
  spec.email         = ["ryan.brendanjohn@gmail.com"]
  spec.description   = %q{A simple ddp client (a la Meteor) written in Ruby}
  spec.summary       = %q{}
  spec.homepage      = "http://github.com/bjryan2/ruby_ddp_client"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "faye-websocket"
  spec.add_development_dependency "json"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
