require 'rails/generators/base'

module Sprig
  module Generators
    class InstallGenerator < Rails::Generators::Base

      desc "Install Sprig seed directories"

      def create_enviroment_directories
        empty_directory 'db/seeds'

        environments.each { |env| empty_directory "db/seeds/#{env}" }
      end

      private

      def environments
        [:development, :test, :integration, :staging, :production]
      end
    end
  end
end
