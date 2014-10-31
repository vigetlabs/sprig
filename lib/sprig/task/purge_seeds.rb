module Sprig
  module Task
    class PurgeSeeds
      include Logging

      def perform
        log_info "Preparing to purge seeds from the #{Rails.env} environment. To purge a different environment, specify the environment as an environment variable (e.g. RAILS_ENV=production)."
        stop 'No seed files to delete. Aborting.' unless seed_files.any?
        list_seed_files
        stop 'Purge aborted.'unless deletion_confirmed?
        delete_seed_files
        log_info 'Seed files deleted.'
      end

      private

      def stop(error_message)
        log_error error_message
        abort
      end

      def list_seed_files
        log_debug 'Files to be deleted:'
        seed_files.each do |filename|
          log_debug "- #{File.basename(filename)}"
        end
      end

      def seed_files
        @seed_files ||= Dir.glob("#{seed_directory}/*")
      end

      def seed_directory
        Sprig.configuration.directory
      end

      def deletion_confirmed?
        log_debug "Are you sure you want to delete these files? (Type 'yes' to confirm.)"
        input = $stdin.gets.chomp
        input == 'yes' ? true : false
      end

      def delete_seed_files
        seed_files.each do |file|
          if File.directory?(file)
            FileUtils.rm_rf(file)
          else
            File.delete(file)
          end
        end
      end

    end
  end
end
