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

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]

  # TODO: this probably doesn't have to be 4
  s.add_dependency "rails", "~> 4.0.0"

  # TODO: created using step 1 of this post:
  # http://viget.com/extend/rails-engine-testing-with-rspec-capybara-and-factorygirl
  # may want to consult when adding tests
end
