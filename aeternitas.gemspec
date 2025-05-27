# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aeternitas/version'

Gem::Specification.new do |spec|
  spec.name          = 'aeternitas'
  spec.version       = Aeternitas::VERSION
  spec.authors       = ['Michael Prilop', 'Max Kießling']
  spec.email         = ['prilop@infai.org']

  spec.summary       = "æternitas - version 2"
  spec.description   = "æternitas is a tool support polling resources (webpages, APIs)."
  spec.homepage      = "https://github.com/Dietech-Group/aeternitas"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 6.1'
  spec.add_dependency 'redis'
  spec.add_dependency 'connection_pool'
  spec.add_dependency 'aasm'
  spec.add_dependency 'sidekiq', '> 4', '<= 5.2.7'
  spec.add_dependency 'sidekiq-unique-jobs', '~> 5.0'
  spec.add_dependency 'tabstabs'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'sqlite3', '~> 1.4'
  spec.add_development_dependency 'database_cleaner', '~> 1.5'
  spec.add_development_dependency 'rspec-sidekiq', '~> 3.1'
  spec.add_development_dependency 'mock_redis'
end
