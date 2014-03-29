module Sprig
  module Logging
    LOG_LEVELS = {
      debug: :blue,
      info:  :green,
      warn:  :orange,
      error: :red
    }

    LOG_COLORS = {
      blue:   34,
      green:  32,
      orange: 33,
      red:    31
    }

    LOG_LEVELS.each do |level, color|
      define_method("log_#{level}") do |message|
        Sprig.logger.send(level, send(color, message.to_s))
      end
    end

    private

    def colorize(message, color_code)
      "\e[#{color_code}m#{message}\e[0m"
    end

    LOG_COLORS.each do |name, color_code|
      define_method(name) do |message|
        colorize(message, color_code)
      end
    end
  end
end
