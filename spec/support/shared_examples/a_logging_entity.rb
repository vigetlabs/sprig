shared_examples_for "a logging entity" do
  let(:message) { 'A log message.' }

  it "can log a debug" do
    Sprig.logger.should_receive(:debug).with(blue_text(message))

    subject.log_debug(message)
  end

  it "can log info" do
    Sprig.logger.should_receive(:info).with(green_text(message))

    subject.log_info(message)
  end

  it "can log a warning" do
    Sprig.logger.should_receive(:warn).with(orange_text(message))

    subject.log_warn(message)
  end

  it "can log an error" do
    Sprig.logger.should_receive(:error).with(red_text(message))

    subject.log_error(message)
  end
end
