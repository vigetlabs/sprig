require 'active_support/inflector'

module Sprig
  class ProcessNotifier
    include Logging

    def initialize
      @success_count = 0
      @error_count = 0
      @errors = []
    end

    def in_progress(seed)
      log_debug seed.in_progress_text
    end

    def success(seed)
      log_info seed.success_log_text
      @success_count += 1
    end

    def error(seed)
      @errors << seed.record
      log_error seed.error_log_text
      log_error seed.record
      log_error seed.record.errors.messages
      @error_count += 1
    end

    def finished
      log_debug 'Seeding complete.'

      if @success_count > 0
        log_info success_summary
      else
        log_error success_summary
      end

      if @error_count > 0
        log_error error_summary

        @errors.each do |error|
          log_error error
          log_error "#{error.errors.messages}\n"
        end
      end
    end

    private

    def success_summary
      "#{@success_count} #{'seed'.pluralize(@success_count)} successfully planted."
    end

    def error_summary
      "#{@error_count} #{'seed'.pluralize(@error_count)} couldn't be planted:"
    end
  end
end
