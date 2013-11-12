module Sow
  class Planter
    def initialize(seeds)
      @seeds = seeds.to_a
    end

    def sow
      dependency_sorted_seeds.each do |seed|
        plant(seed)
      end

      logger.log_summary
    end

    private

    attr_reader :seeds

    def dependency_sorted_seeds
      Dependency::Sorter.new(seeds).sorted_items
    end

    def logger
      @logger ||= SowLogger.new
    end

    def plant(seed)
      logger.processing
      seed.before_save

      if seed.save_record
        seed.save_to_store
        logger.log_success(seed)
      else
        logger.log_error(seed)
      end
    end
  end
end