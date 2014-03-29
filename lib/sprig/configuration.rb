module Sprig
  class Configuration

    attr_writer :directory, :logger

    def directory
      Rails.root.join(@directory || default_directory, Rails.env)
    end

    def logger
      @logger ||= Logger.new($stdout)
    end

    private

    def default_directory
      'db/seeds'
    end
  end
end
