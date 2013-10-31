module Sow
  class Manager
    def initialize(seeds)
      @seeds = seeds
    end

    def sow
      @seeds.each do |seed|
        SeedTask.new(seed, logger).sow
      end

      @logger.log_summary
    end

    private

    def logger
      @logger ||= SeedLogger.new
    end
  end
end
