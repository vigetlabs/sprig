module Sprig
  module Helpers
    def seed_directory
      Sprig.configuration.directory
    end

    def sprig(directive_definitions)
      Sprig.shared_seeding = false
      plant_records(directive_definitions)
    end

    def sprig_shared(directive_definitions)
      Sprig.shared_seeding = true
      plant_records(directive_definitions)
    end

    def sprig_record(klass, seed_id)
      SprigRecordStore.instance.get(klass, seed_id)
    end

    def sprig_file(relative_path)
      File.new(seed_directory.join("files", relative_path))
    end

    private

    def plant_records(directive_definitions)
      # The DependencyCollection and SprigRecordStore are SESSION persistent, not run persistent;
      # explicitly reset them both to avoid cross-run stale data
      DependencyCollection.instance.reset
      SprigRecordStore.instance.reset

      hopper = []
      DirectiveList.new(directive_definitions).add_seeds_to_hopper(hopper)
      Planter.new(hopper).sprig
    end
  end
end
