$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "sow/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "sow"
  s.version     = Sow::VERSION
  s.authors     = ["Lawson Kurtz"]
  s.email       = ["lawson.kurtz@viget.com"]
  s.homepage    = "http://www.github.com/vigetlabs/sow"
  s.summary     = "Sow your seed data."
  s.description = "Sow is a library for managing environment specific seed data."

  s.files = Dir["lib/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["spec/**/*"]

  s.add_development_dependency "rails",            "~> 3.1"
  s.add_development_dependency "sqlite3",          "~> 1.3.8"
  s.add_development_dependency "rspec",            "~> 2.14.0"
  s.add_development_dependency "database_cleaner", "~> 1.2.0"
  s.add_development_dependency "webmock",          "~> 1.16.1"
  s.add_development_dependency "vcr",              "~> 2.8.0"
  s.add_development_dependency "pry"  
end
