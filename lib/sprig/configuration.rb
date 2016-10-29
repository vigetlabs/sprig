module Sprig
  class Configuration

    attr_writer :directory, :seeds_directory, :logger

    def directory
      Rails.root.join(@directory || default_directory, @seeds_directory || default_seeds_directory)
    end

    def logger
      @logger ||= Logger.new($stdout)
    end

    private

    def default_directory
      'db/seeds'
    end

    def default_seeds_directory
      Rails.env
    end
  end
end
