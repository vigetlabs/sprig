module Sow
  module Helpers
    def seeded_record(klass, seed_id)
      SeededRecordStore.instance.get(klass, seed_id)
    end

    def seed_file(relative_path)
      File.open(Rails.root.join('db', 'seeds', Rails.env, 'files', relative_path))
    end
  end
end
