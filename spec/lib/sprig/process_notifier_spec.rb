require 'spec_helper'

describe Sprig::ProcessNotifier do
  it_behaves_like "a logging entity" do
    subject { described_class.new }
  end

  describe "#success" do
    let(:seed) { double('Seed', success_log_text: 'I am a teapot.') }

    it "logs the seed's success message" do
      Sprig.logger.should_receive(:info).with(green_text('I am a teapot.'))

      subject.success(seed)
    end
  end

  describe "#error" do
    let(:errors) { double('Errors', messages: 'error messages') }
    let(:seed_record) { double('Record', to_s: 'Seed Record', errors: errors) }
    let(:seed) { double('Seed', error_log_text: 'I am a teapot.', record: seed_record) }

    it "logs the seed's error message and error details" do
      Sprig.logger.should_receive(:error).with(red_text('I am a teapot.')).ordered
      Sprig.logger.should_receive(:error).with(red_text('Seed Record')).ordered
      Sprig.logger.should_receive(:error).with(red_text('error messages')).ordered

      subject.error(seed)
    end
  end

  describe "#finished" do
    it "logs a complete message" do
      Sprig.logger.should_receive(:debug).with(blue_text('Seeding complete.'))

      subject.finished
    end

    context "when records are saved successfully" do
      let(:seed) { double('Seed', success_log_text: 'I am a teapot.') }

      before do
        subject.success(seed)
      end

      it "logs a summery of successful saves" do
        Sprig.logger.should_receive(:info).with(green_text('1 seed successfully planted.'))

        subject.finished
      end
    end

    context "when no records are saved successfully" do
      it "logs a summery of successful saves" do
        Sprig.logger.should_receive(:error).with(red_text('0 seeds successfully planted.'))

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
        Sprig.logger.should_receive(:error).with(red_text('0 seeds successfully planted.')).ordered
        Sprig.logger.should_receive(:error).with(red_text("1 seed couldn't be planted:")).ordered
        Sprig.logger.should_receive(:error).with(red_text('Seed Record')).ordered
        Sprig.logger.should_receive(:error).with(red_text("error messages\n")).ordered

        subject.finished
      end
    end
  end

  describe "#in_progress" do
    it "logs an in-progress message" do
      Sprig.logger.should_receive(:debug).with(blue_text("Planting those seeds...\r"))

      subject.in_progress
    end
  end
end
