module Sprig
  class Configuration

    attr_writer :directory, :logger, :wrap_in_transaction

    def directory
      Rails.root.join(@directory || default_directory, Rails.env)
    end

    def logger
      @logger ||= Logger.new($stdout)
    end

    def wrap_in_transaction
      defined?(@wrap_in_transaction) ? @wrap_in_transaction : false
    end

    private

    def default_directory
      'db/seeds'
    end
  end
end
