shared_examples_for "a logging entity" do
  let(:message) { 'A log message.' }

  [
    :debug,
    :info,
    :warn,
    :error
  ].each do |level|
    it "can log a #{level}" do
      log_should_receive(level, with: message)

      subject.send("log_#{level}", message)
    end
  end
end
