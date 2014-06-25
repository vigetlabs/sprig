module Sprig
  module Helpers
    def seed_directory
      Sprig.configuration.directory
    end

    def sprig(directive_definitions)
      hopper = []
      DirectiveList.new(directive_definitions).add_seeds_to_hopper(hopper)
      Planter.new(hopper).sprig
    end

    def sprig_record(klass, seed_id)
      SprigRecordStore.instance.get(klass, seed_id)
    rescue SprigRecordStore::RecordNotFoundError => error
      NullRecord.new(error)
    end

    def sprig_file(relative_path)
      File.new(seed_directory.join('files', relative_path))
    end
  end
end
