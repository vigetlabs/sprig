module Sprig
  class Configuration

    attr_writer :directory

    def directory
      Rails.root.join(@directory || default_directory, Rails.env)
    end

    private

    def default_directory
      'db/seeds'
    end
  end
end
