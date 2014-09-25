namespace :db do
  namespace :seed do

    desc 'Purge seed files'
    task :purge do
      check_args
      list_seed_files
      delete_seed_files if deletion_confirmed?
    end

    def deletion_confirmed?
      puts "\nAre you sure? (yes/no)"
      input = STDIN.gets.chomp
      input == 'yes' ? true : false      
    end

    def check_args
      unless ENV['ENVIRONMENT']
        abort('Expected environment argument e.g. ENVIRONMENT=development. Aborting.')
      end
    end

    def list_seed_files
      filenames = seed_filenames
      if filenames.empty?
        abort('No files to delete. Aborting')
      else
        puts 'Files to be deleted:'
        filenames.each { |filename| puts "#{File.basename(filename)}" }
      end
    end

    def delete_seed_files
      seed_filenames.each { |filename| File.delete(filename) }
      puts 'Seed files deleted.'
    end

    def seed_filenames
      seed_files_path = Rails.root.join('db', 'seeds', ENV['ENVIRONMENT'])
      Dir.glob("#{seed_files_path}/*.{yml,yaml,json,csv}")
    end
  end
end
