module Sprig
  class Configuration

    attr_writer :directory, :shared_directory, :logger

    def directory
      Rails.root.join(@directory || default_directory, seeds_directory)
    end

    def logger
      @logger ||= Logger.new($stdout)
    end

    private

    def default_directory
      'db/seeds'
    end

    def seeds_directory
      return shared_seeds_directory if Sprig.shared_seeding
      env_seeds_directory
    end

    def env_seeds_directory
      Rails.env
    end

    def shared_seeds_directory
      @shared_directory || default_shared_directory
    end

    def default_shared_directory
      'shared'
    end
  end
end
