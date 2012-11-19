# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rfc-ws-client/version'

Gem::Specification.new do |gem|
  gem.name          = "rfc-ws-client"
  gem.version       = RfcWebsocket::VERSION
  gem.authors       = ["Lucas Clemente"]
  gem.email         = ["luke.clemente@gmail.com"]
  gem.summary       = %q{A simple Websocket client in ruby}
  gem.homepage      = "https://github.com/lucas-clemente/rfc-ws-client"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
