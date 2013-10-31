require "sow/engine"

module Sow
  gem_path = Gem.loaded_specs['sow'].full_gem_path
  Dir[File.join(gem_path, "lib/sow/**/*.rb")].each {|f| require f}
end
