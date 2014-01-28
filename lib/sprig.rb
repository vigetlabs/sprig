module Sprig
  autoload :Configuration,        'sprig/configuration'
  autoload :Planter,              'sprig/planter'
  autoload :Dependency,           'sprig/dependency'
  autoload :DependencyCollection, 'sprig/dependency_collection'
  autoload :DependencySorter,     'sprig/dependency_sorter'
  autoload :Directive,            'sprig/directive'
  autoload :DirectiveList,        'sprig/directive_list'
  autoload :Source,               'sprig/source'
  autoload :Parser,               'sprig/parser'
  autoload :Helpers,              'sprig/helpers'
  autoload :Planter,              'sprig/planter'
  autoload :SprigLogger,            'sprig/sprig_logger'
  autoload :SprigRecordStore,      'sprig/sprig_record_store'
  autoload :Data,                 'sprig/data'
  autoload :Seed,                 'sprig/seed'

  def self.configuration
    @@configuration ||= Sprig::Configuration.new
  end

  def self.configure
    yield configuration
  end

  def self.reset_configuration
    @@configuration = nil
  end
end
