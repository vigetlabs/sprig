require "active_support/inflector"

module Sprig
  class ProcessNotifier
    include Logging

    def initialize
      @success_count = 0
      @error_count = 0
      @failure_summaries = []
      @success_summaries = []
      @rolled_back = false
    end

    def in_progress(seed)
      log_debug seed.in_progress_text
    end

    def success(seed)
      log_info seed.success_log_text
      @success_count += 1
      @success_summaries << seed.success_summary_text
    end

    def warning(message)
      log_warn message
    end

    def error(seed)
      log_error seed.error_log_text
      log_error seed.record
      log_error seed.record.errors.messages

      record_failure(seed.error_log_text)
    end

    def exception(seed, error)
      log_error seed.error_log_text
      log_error "#{error.class}: #{error.message}"

      record_failure(seed.error_log_text)
    end

    def errors?
      @error_count > 0
    end

    def rollback
      @rolled_back = true
    end

    def finished
      log_debug "Seeding complete."

      if @rolled_back
        report_rollback
      else
        report_completion
      end
    end

    private

    def report_rollback
      log_error rollback_summary

      if @success_count > 0
        log_error would_have_planted_summary

        @success_summaries.each do |summary|
          log_error summary
        end
      end

      log_error error_summary

      @failure_summaries.each do |summary|
        log_error summary
      end
    end

    def report_completion
      if @success_count > 0
        log_info success_summary
      else
        log_error success_summary
      end

      if @error_count > 0
        log_error error_summary

        @failure_summaries.each do |summary|
          log_error summary
        end
      end
    end

    def record_failure(summary)
      @failure_summaries << summary
      @error_count += 1
    end

    def success_summary
      "#{@success_count} #{"seed".pluralize(@success_count)} successfully planted."
    end

    def rollback_summary
      "The seeding transaction was rolled back because #{@error_count} #{"seed".pluralize(@error_count)} " \
        "failed to plant. NO records from this run were actually saved to the database."
    end

    def would_have_planted_summary
      "The following #{@success_count} #{"seed".pluralize(@success_count)} would have been planted, " \
        "but were rolled back along with everything else and were NOT saved:"
    end

    def error_summary
      "#{@error_count} #{"seed".pluralize(@error_count)} couldn't be planted:"
    end
  end
end
