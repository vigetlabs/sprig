module Sprig
  autoload :Configuration,        'sprig/configuration'
  autoload :Planter,              'sprig/planter'
  autoload :TsortableHash,        'sprig/tsortable_hash'
  autoload :Dependency,           'sprig/dependency'
  autoload :DependencyCollection, 'sprig/dependency_collection'
  autoload :DependencySorter,     'sprig/dependency_sorter'
  autoload :Directive,            'sprig/directive'
  autoload :DirectiveList,        'sprig/directive_list'
  autoload :Source,               'sprig/source'
  autoload :Parser,               'sprig/parser'
  autoload :Helpers,              'sprig/helpers'
  autoload :Planter,              'sprig/planter'
  autoload :ProcessNotifier,      'sprig/process_notifier'
  autoload :Logging,              'sprig/logging'
  autoload :NullRecord,           'sprig/null_record'
  autoload :SprigRecordStore,     'sprig/sprig_record_store'
  autoload :Data,                 'sprig/data'
  autoload :Seed,                 'sprig/seed'

  class << self
    attr_writer :adapter

    def adapter
      @adapter ||= :active_record
    end

    def adapter_model_class
      @adapter_model_class ||= case adapter
      when :active_record
        ActiveRecord::Base
      when :mongoid
        Mongoid::Document
      else
        raise "Unknown model class for adapter #{adapter}"
      end
    end

    def configuration
      @@configuration ||= Sprig::Configuration.new
    end

    def configure
      yield configuration
    end

    def reset_configuration
      @@configuration = nil
    end

    def logger
      configuration.logger
    end
  end
end
