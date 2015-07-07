require 'spec_helper'

describe Sprig::ProcessNotifier do
  it_behaves_like "a logging entity" do
    subject { described_class.new }
  end

  describe "#success" do
    let(:seed) { double('Seed', success_log_text: 'I am a teapot.') }

    it "logs the seed's success message" do
      log_should_receive(:info, with: 'I am a teapot.')

      subject.success(seed)
    end
  end

  describe "#error" do
    let(:errors) { double('Errors', messages: 'error messages') }
    let(:seed_record) { double('Record', to_s: 'Seed Record', errors: errors) }
    let(:seed) { double('Seed', error_log_text: 'I am a teapot.', record: seed_record) }

    it "logs the seed's error message and error details" do
      log_should_receive(:error, with: 'I am a teapot.').ordered
      log_should_receive(:error, with: 'Seed Record').ordered
      log_should_receive(:error, with: 'error messages').ordered

      subject.error(seed)
    end
  end

  describe "#finished" do
    it "logs a complete message" do
      log_should_receive(:debug, with: 'Seeding complete.')

      subject.finished
    end

    context "when records are saved successfully" do
      let(:seed) { double('Seed', success_log_text: 'I am a teapot.') }

      before do
        subject.success(seed)
      end

      it "logs a summery of successful saves" do
        log_should_receive(:info, with: '1 seed successfully planted.')

        subject.finished
      end
    end

    context "when no records are saved successfully" do
      it "logs a summery of successful saves" do
        log_should_receive(:error, with: '0 seeds successfully planted.')

        subject.finished
      end
    end

    context "when there is an error saving a record" do
      let(:errors) { double('Errors', messages: 'error messages') }
      let(:seed_record) { double('Record', to_s: 'Seed Record', errors: errors) }
      let(:seed) { double('Seed', error_log_text: 'I am a teapot.', record: seed_record) }

      before do
        subject.error(seed)
      end

      it "logs a summary of errors" do
        log_should_receive(:error, with: '0 seeds successfully planted.').ordered
        log_should_receive(:error, with: "1 seed couldn't be planted:").ordered
        log_should_receive(:error, with: 'Seed Record').ordered
        log_should_receive(:error, with: "error messages\n").ordered

        subject.finished
      end
    end
  end

  describe "#in_progress" do
    let(:seed) { Sprig::Seed::Entry.new(Post, { title: "Hello World!", content: "Stuff", sprig_id: 1 }, {}) }

    it "logs an in-progress message" do
      log_should_receive(:debug, with: "Planting Post with sprig_id 1")

      subject.in_progress(seed)
    end
  end
end
