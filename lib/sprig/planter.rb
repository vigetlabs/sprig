module Sprig
  class Planter
    def initialize(seeds)
      @seeds = seeds.to_a
    end

    def sprig
      wrap_in_transaction_if_supported do
        dependency_sorted_seeds.each do |seed|
          plant(seed)
        end
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
        raise ActiveRecord::Rollback if transactional_wrapping_requested_and_supported?
        notifier.error(seed)
      end
    end

    def transactional_wrapping_requested_and_supported?
      Sprig.configuration.wrap_in_transaction && Sprig.adapter == :active_record
    end

    def wrap_in_transaction_if_supported
      return yield unless Sprig.configuration.wrap_in_transaction

      if Sprig.adapter != :active_record
        notifier.warn("Only the `:active_record` adapter supports transactional wrapping. You specified `#{Sprig.adapter}`.")
        return yield
      end

      Sprig.adapter_model_class.transaction do
        yield
      end
    end
  end
end
