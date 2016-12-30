# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cauchy/version'

Gem::Specification.new do |s|
  s.name          = 'cauchy'
  s.version       = Cauchy::VERSION
  s.authors       = ['Paul Hamera', 'Evan Owen']
  s.email         = ['paul@zinc.it', 'evan@zinc.it']

  s.summary       = 'An elasticsearch schema management tool'
  s.description   = 'An elasticsearch schema management tool'
  s.homepage      = 'https://github.com/cotap'
  s.license       = 'MIT'

  s.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  s.executables = Dir['bin/*'].map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 2.0.0'

  s.add_dependency 'activesupport', '>= 4.2'
  s.add_dependency 'diffy', '~> 3.1'
  s.add_dependency 'elasticsearch', '~> 1.0'
  s.add_dependency 'indentation', '~> 0.0'
  s.add_dependency 'json', '>= 1.8'
  s.add_dependency 'rainbow', '~> 2.1'
  s.add_dependency 'ruby-progressbar', '~> 1.8'
  s.add_dependency 'thor', '~> 0.18'

  s.add_development_dependency 'bundler', '~> 1.11'
  s.add_development_dependency 'codecov', '~> 0.1.9'
  s.add_development_dependency 'rake', '~> 10.0'
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rspec-its', '~> 1.2'
  s.add_development_dependency 'pry'
end
