module LoggerMock

  def log_should_receive(level, options)
    expect(Sprig.logger).to receive(level).with(send("log_#{level}_text", options.fetch(:with)))
  end

  def log_debug_text(text)
    blue_text(text)
  end

  def log_info_text(text)
    green_text(text)
  end

  def log_warn_text(text)
    orange_text(text)
  end

  def log_error_text(text)
    red_text(text)
  end
end
