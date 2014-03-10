module Sprig
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc 'Creates environment-specific Sprig gem configuration files at db/seeds'

      def create_seed_directory
        FileUtils.mkdir_p(seeds_dir)
      end

      def create_config_directories
        Dir['config/environments/*.rb'].each do |env_filename|
          environment_name = config_file_name(env_filename)
          directory_path = directory_path(environment_name)
          unless File.directory?(directory_path)
            FileUtils.mkdir_p(directory_path)
            created_message(directory_path)
          end
        end
      end

      private

      def seeds_dir
        'db/seeds'
      end

      def config_file_name(env_filename)
        File.basename(env_filename, File.extname(env_filename))
      end

      def directory_path(environment_name)
        File.join(seeds_dir, File.basename(environment_name))
      end

      def created_message(directory_path)
        puts "    \e[32mcreate\e[0m #{directory_path}"
      end
    end
  end
end
