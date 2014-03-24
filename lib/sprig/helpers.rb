module Sprig
  module Helpers

    class NullRecord
      def method_missing(*)
        nil
      end
    end

    def seed_directory
      Sprig.configuration.directory
    end

    def sprig_environment
      Rails.env #TODO: make customizable
    end

    def sprig(directive_definitions)
      hopper = []
      DirectiveList.new(directive_definitions).add_seeds_to_hopper(hopper)
      Planter.new(hopper).sprig
    end

    def sprig_record(klass, seed_id)
      SprigRecordStore.instance.get(klass, seed_id)
    rescue SprigRecordStore::RecordNotFoundError => error
      sprig_record_not_found(error)
    end

    def sprig_file(relative_path)
      File.new(seed_directory.join('files', relative_path))
    end

    def sprig_record_not_found(error)
      puts "\e[#{31}m#{error}\e[0m"
      return NullRecord.new
    end
  end
end
