require "spec_helper"

RSpec.describe Sprig::ProcessNotifier do
  it_behaves_like "a logging entity" do
    subject { described_class.new }
  end

  describe "#success" do
    let(:seed) { double("Seed", success_log_text: "I am a teapot.", success_summary_text: "Teapot with sprig_id 1 (I am a teapot.)") }

    it "logs the seed's success message" do
      log_should_receive(:info, with: "I am a teapot.")

      subject.success(seed)
    end
  end

  describe "#warning" do
    it "logs the provided message as a warning" do
      message = "oh noes!"
      log_should_receive(:warn, with: message)

      subject.warning(message)
    end
  end

  describe "#error" do
    let(:errors) { double("Errors", messages: "error messages") }
    let(:seed_record) { double("Record", to_s: "Seed Record", errors: errors) }
    let(:seed) { double("Seed", error_log_text: "I am a teapot.", record: seed_record) }

    it "logs the seed's error message and error details" do
      log_should_receive(:error, with: "I am a teapot.").ordered
      log_should_receive(:error, with: "Seed Record").ordered
      log_should_receive(:error, with: "error messages").ordered

      subject.error(seed)
    end
  end

  describe "#exception" do
    let(:seed) { double("Seed", error_log_text: "I am a teapot.") }
    let(:error) { RuntimeError.new("Something went wrong.") }

    it "logs the seed's error message and the exception" do
      log_should_receive(:error, with: "I am a teapot.").ordered
      log_should_receive(:error, with: "RuntimeError: Something went wrong.").ordered

      subject.exception(seed, error)
    end
  end

  describe "#finished" do
    it "logs a complete message" do
      log_should_receive(:debug, with: "Seeding complete.")

      subject.finished
    end

    context "when records are saved successfully" do
      let(:seed) { double("Seed", success_log_text: "I am a teapot.", success_summary_text: "Teapot with sprig_id 1 (I am a teapot.)") }

      before do
        subject.success(seed)
      end

      it "logs a summery of successful saves" do
        log_should_receive(:info, with: "1 seed successfully planted.")

        subject.finished
      end
    end

    context "when no records are saved successfully" do
      it "logs a summery of successful saves" do
        log_should_receive(:error, with: "0 seeds successfully planted.")

        subject.finished
      end
    end

    context "when there is an error saving a record" do
      let(:errors) { double("Errors", messages: "error messages") }
      let(:seed_record) { double("Record", to_s: "Seed Record", errors: errors) }
      let(:seed) { double("Seed", error_log_text: "I am a teapot.", record: seed_record) }

      before do
        subject.error(seed)
      end

      it "logs a summary of errors" do
        log_should_receive(:error, with: "0 seeds successfully planted.").ordered
        log_should_receive(:error, with: "1 seed couldn't be planted:").ordered
        log_should_receive(:error, with: "I am a teapot.").ordered

        subject.finished
      end
    end

    context "when the run has been rolled back" do
      let(:successful_seed) { double("Seed", success_log_text: "Saved", success_summary_text: "Post with sprig_id 1 (Saved)") }
      let(:errors) { double("Errors", messages: "error messages") }
      let(:seed_record) { double("Record", to_s: "Seed Record", errors: errors) }
      let(:failed_seed) { double("Seed", error_log_text: "There was an error saving Post with sprig_id 2.", record: seed_record) }

      before do
        subject.success(successful_seed)
        subject.error(failed_seed)
        subject.rollback
      end

      it "explains the rollback, lists what would have been planted, and lists what failed" do
        log_should_receive(:error, with: "The seeding transaction was rolled back because 1 seed failed to plant. NO records from this run were actually saved to the database.").ordered
        log_should_receive(:error, with: "The following 1 seed would have been planted, but were rolled back along with everything else and were NOT saved:").ordered
        log_should_receive(:error, with: "Post with sprig_id 1 (Saved)").ordered
        log_should_receive(:error, with: "1 seed couldn't be planted:").ordered
        log_should_receive(:error, with: "There was an error saving Post with sprig_id 2.").ordered

        subject.finished
      end

      it "does not log the usual success summary" do
        allow(Sprig.logger).to receive(:error)
        expect(Sprig.logger).to_not receive(:info)

        subject.finished
      end
    end

    context "when the run has been rolled back with no successful seeds" do
      let(:errors) { double("Errors", messages: "error messages") }
      let(:seed_record) { double("Record", to_s: "Seed Record", errors: errors) }
      let(:failed_seed) { double("Seed", error_log_text: "There was an error saving Post with sprig_id 2.", record: seed_record) }

      before do
        subject.error(failed_seed)
        subject.rollback
      end

      it "skips the would-have-planted section" do
        log_should_receive(:error, with: "The seeding transaction was rolled back because 1 seed failed to plant. NO records from this run were actually saved to the database.").ordered
        log_should_receive(:error, with: "1 seed couldn't be planted:").ordered
        log_should_receive(:error, with: "There was an error saving Post with sprig_id 2.").ordered

        subject.finished
      end
    end
  end

  describe "#in_progress" do
    let(:seed) { Sprig::Seed::Entry.new(Post, {title: "Hello World!", content: "Stuff", sprig_id: 1}, {}) }

    it "logs an in-progress message" do
      log_should_receive(:debug, with: "Planting Post with sprig_id 1")

      subject.in_progress(seed)
    end
  end
end
