# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "thrift/rack_middleware/version"

Gem::Specification.new do |s|
  s.name        = "thrift-rack-middleware"
  s.version     = Thrift::Rack::Middleware::VERSION
  s.authors     = ["deees"]
  s.email       = ["tomas.brazys@gmail.com"]
  s.homepage    = "http://github.com/deees/thrift-rack-middleware"
  s.summary     = "Thrift rack middleware"
  s.description = "Rack middleware for thrift services"

  s.rubyforge_project = "thrift-rack-middleware"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "rspec"
  s.add_runtime_dependency "rack", '>= 1.1.0'
  s.add_runtime_dependency "thrift", ">= 0.9.0"
end
