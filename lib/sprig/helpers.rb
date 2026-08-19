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

      planter = Planter.new(transactional_anchor_class_hint(directive_definitions))
      planter.sprig do
        DirectiveList.new(directive_definitions).add_seeds_to_hopper(planter)
      end
    end

    # The class of the first directive being seeded, used only as a Mongoid
    # transaction anchor (see Planter#transactional_anchor_class) -- cheap to
    # compute from the directive definitions themselves, before any file is
    # opened or parsed, unlike reading a class off of a to-be-parsed record.
    def transactional_anchor_class_hint(directive_definitions)
      first_definition = Array(directive_definitions).first
      first_definition && Directive.new(first_definition).klass
    end
  end
end
