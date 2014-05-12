require 'rails/generators/base'

module Sprig
  module Generators
    class InstallGenerator < Rails::Generators::Base
      argument :arg_envs, :type => :array, :optional => true

      desc "Install Sprig seed directories"

      def create_enviroment_directories
        empty_directory 'db/seeds'

        envs.each { |env| empty_directory "db/seeds/#{env}" }
      end

      private

      def envs
        arg_envs ? arg_envs : default_envs
      end

      def default_envs
        env_configs.map { |p| File.basename(p, File.extname(p)) }
      end

      def env_configs
        Dir[Rails.root.join('config/environments', '*.rb')]
      end
    end
  end
end
