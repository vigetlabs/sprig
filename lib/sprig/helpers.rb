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
      # SprigRecordStore is SESSION persistent, not run persistent; explicitly reset it
      # to avoid cross-run stale data
      SprigRecordStore.instance.reset
      RawRowStore.instance.reset if Sprig.configuration.spill_seed_rows_to_disk

      planter = Planter.new(transactional_anchor_class_hint(directive_definitions))
      begin
        planter.sprig do
          DirectiveList.new(directive_definitions).add_seeds_to_hopper(planter)
        end
      ensure
        RawRowStore.instance.cleanup if Sprig.configuration.spill_seed_rows_to_disk
      end
    end

    # The class of the first directive being seeded, used only as a Mongoid
    # transaction anchor (see Planter#transactional_anchor_class)
    def transactional_anchor_class_hint(directive_definitions)
      first_definition = Array(directive_definitions).first
      first_definition && Directive.new(first_definition).klass
    end
  end
end
