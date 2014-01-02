module Sow
  module Helpers
    def seed_directory
      Rails.root.join('db', 'seeds', sow_environment) #TODO: make customizable
    end

    def sow_environment
      Rails.env #TODO: make customizable
    end

    def sow(directive_definitions)
      hopper = []
      DirectiveList.new(directive_definitions).add_seeds_to_hopper(hopper)
      Planter.new(hopper).sow
    end

    def sow_record(klass, seed_id)
      SownRecordStore.instance.get(klass, seed_id)
    end

    def sow_file(relative_path)
      File.new(seed_directory.join('files', relative_path))
    end
  end
end
