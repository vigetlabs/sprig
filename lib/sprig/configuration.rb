module Sprig
  class Configuration

    attr_writer :directory, :logger, :shared_directory

    def directory
      Rails.root.join(@directory || default_directory, source_directory)
    end

    def shared_directory
      @shared_directory
    end

    def logger
      @logger ||= Logger.new($stdout)
    end

    private

    def source_directory
      shared_directory || Rails.env
    end

    def default_directory
      'db/seeds'
    end
  end
end
