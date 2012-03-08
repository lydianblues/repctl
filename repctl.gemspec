# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "repctl/version"

Gem::Specification.new do |s|
  s.name        = "repctl"
  s.version     = Repctl::VERSION
  s.authors     = ["Michael Schmitz"]
  s.email       = ["lydianblues@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Manage replication for Mysql and PostgresSQL}
  s.description = %q{Ruby gem with Thor script to manage MySQL and PostgreSQL replication}

  s.rubyforge_project = "repctl"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "rspec"
  s.add_development_dependency "shotgun"
  s.add_development_dependency "compass"
  s.add_runtime_dependency "thor"
  s.add_runtime_dependency "mysql2"
  s.add_runtime_dependency "sinatra"
  s.add_runtime_dependency "thin"
 
end
