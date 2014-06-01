module Sprig
  module Harvest
    autoload :Model,    'sprig/harvest/model'
    autoload :Record,   'sprig/harvest/record'
    autoload :SeedFile, 'sprig/harvest/seed_file'

    # TODO Allow `.reap` to take options:
    # Environment
    # Subset of ActiveRecord::Base-descendant models (instead of grabbing all of them)

    def self.reap
      Model.all.each { |model| SeedFile.new(model).write }
    end
  end
end
