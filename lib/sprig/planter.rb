module Sprig
  class Planter
    def initialize(seeds)
      @seeds = seeds.to_a
    end

    def sprig
      dependency_sorted_seeds.each do |seed|
        plant(seed)
      end

      notifier.finished
    end

    private

    attr_reader :seeds

    def dependency_sorted_seeds
      DependencySorter.new(seeds).sorted_items
    end

    def notifier
      @notifier ||= ProcessNotifier.new
    end

    def plant(seed)
      notifier.in_progress(seed)
      seed.before_save

      if seed.save_record
        seed.save_to_store
        notifier.success(seed)
      else
        notifier.error(seed)
      end
    end
  end
end
