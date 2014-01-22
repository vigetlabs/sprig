module Sow
  autoload :Configuration, 'sow/configuration'
  autoload :Planter, 'sow/planter'
  autoload :Dependency, 'sow/dependency'
  autoload :DependencyCollection, 'sow/dependency_collection'
  autoload :DependencySorter, 'sow/dependency_sorter'
  autoload :Directive, 'sow/directive'
  autoload :DirectiveList, 'sow/directive_list'
  autoload :Helpers, 'sow/helpers'
  autoload :Planter, 'sow/planter'
  autoload :SowLogger, 'sow/sow_logger'
  autoload :SownRecordStore, 'sow/sown_record_store'
  autoload :Data, 'sow/data'
  autoload :Seed, 'sow/seed'

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
