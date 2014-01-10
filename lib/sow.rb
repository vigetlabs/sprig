module Sow
  gem_path = Gem.loaded_specs['sow'].full_gem_path
  Dir[File.join(gem_path, "lib/sow/**/*.rb")].each {|f| require f}

  def self.configuration
    @@configuration ||= Sow::Configuration.new
  end

  def self.configure
    yield configuration
  end

  def self.reset_configuration
    @@configuration = nil
  end
end
