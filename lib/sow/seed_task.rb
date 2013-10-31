module Sow
  class SeedTask
    def initialize(seed, logger)
      @seed = seed
      @logger = logger
    end

    def sow
      @logger.processing
      @seed.prepare

      if @seed.save_record
        @seed.save_to_store
        @logger.log_success(@seed)
      else
        @logger.log_error(@seed)
      end
    end
  end
end
