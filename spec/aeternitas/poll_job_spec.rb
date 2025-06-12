require "spec_helper"

RSpec.describe Aeternitas::PollJob do
  let(:pollable) { FullPollable.create!(name: "Test Pollable") }
  let(:meta_data) { pollable.pollable_meta_data }

  describe "#perform" do
    it "finds the PollableMetaData and calls execute_poll on the pollable" do
      job_instance = described_class.new(meta_data.id)
      allow(Aeternitas::PollableMetaData).to receive(:find_by).with(id: meta_data.id).and_return(meta_data)
      expect(meta_data.pollable).to receive(:execute_poll)
      job_instance.perform_now
    end

    it "cleans up the unique lock on successful execution" do
      described_class.perform_later(meta_data.id)
      expect(Aeternitas::UniqueJobLock.count).to eq(1)

      perform_enqueued_jobs

      expect(Aeternitas::UniqueJobLock.count).to eq(0)
    end
  end

  describe "Uniqueness Logic" do
    it "creates a unique lock on enqueue" do
      expect {
        described_class.perform_later(meta_data.id)
      }.to change(Aeternitas::UniqueJobLock, :count).by(1)
    end

    it "sets the lock expiration correctly" do
      travel_to Time.current do
        described_class.perform_later(meta_data.id)
        lock = Aeternitas::UniqueJobLock.last
        expect(lock.expires_at).to be_within(1.second).of(1.month.from_now)
      end
    end

    it "prevents a duplicate job from being enqueued" do
      described_class.perform_later(meta_data.id)
      expect(enqueued_jobs.size).to eq(1)

      expect {
        described_class.perform_later(meta_data.id)
      }.to change(enqueued_jobs, :size).by(0)

      expect(Aeternitas::UniqueJobLock.count).to eq(1)
    end

    context "when an expired lock exists" do
      before do
        digest = described_class.send(:generate_lock_digest, meta_data.id)
        Aeternitas::UniqueJobLock.create!(lock_digest: digest, job_id: "stale_job", expires_at: 1.day.ago)
      end

      it "clears the expired lock and enqueues the new job" do
        expect {
          described_class.perform_later(meta_data.id)
        }.to change(enqueued_jobs, :size).by(1)

        expect(Aeternitas::UniqueJobLock.count).to eq(1)
        expect(Aeternitas::UniqueJobLock.last.job_id).not_to eq("stale_job")
      end
    end
  end

  describe "Retry and Exhaustion Logic" do
    before do
      allow_any_instance_of(FullPollable).to receive(:execute_poll).and_raise("Polling Failed")
    end

    it "retries the job with the correct backoff delays" do
      travel_to Time.current do
        described_class.perform_later(meta_data.id)
        expect(Aeternitas::UniqueJobLock.count).to eq(1)

        # initial attempt fails and re-enqueues
        perform_enqueued_jobs
        expect(enqueued_jobs.size).to eq(1)
        enqueued_job = enqueued_jobs.last
        expect(Time.at(enqueued_job[:at])).to be_within(1.second).of(1.minute.from_now)
        expect(Aeternitas::UniqueJobLock.count).to eq(1) # Lock persists
      end
    end

    context "when retries are exhausted" do
      before do
        digest = described_class.send(:generate_lock_digest, meta_data.id)
        Aeternitas::UniqueJobLock.create!(lock_digest: digest, expires_at: 1.month.from_now)
      end

      it "disables the pollable and cleans up the lock" do
        expect(Aeternitas::UniqueJobLock.count).to eq(1)

        job_instance = described_class.new(meta_data.id)
        error = RuntimeError.new("Polling Failed")
        job_instance.handle_retries_exhausted(error)

        meta_data.reload
        expect(meta_data.deactivated?).to be true
        expect(meta_data.deactivation_reason).to include("Polling Failed")
        expect(Aeternitas::UniqueJobLock.count).to eq(0)
        expect(enqueued_jobs).to be_empty
      end
    end
  end

  describe "GuardIsLocked Handling" do
    let(:guard_locked_error) { Aeternitas::Guard::GuardIsLocked.new("guard-key", 30.minutes.from_now) }

    before do
      allow_any_instance_of(Aeternitas::Guard).to receive(:with_lock).and_raise(guard_locked_error)
    end

    context "when sleep_on_guard_locked is true" do
      let(:pollable_with_sleep) { SimplePollable.create!(name: "Sleeper") }
      let(:meta_data_with_sleep) { pollable_with_sleep.pollable_meta_data }

      before do
        pollable_with_sleep.pollable_configuration.sleep_on_guard_locked = true
      end

      it "blocks with sleep, sets state to enqueued, and retries the job" do
        travel_to Time.current do
          job_instance = described_class.new(meta_data_with_sleep.id)

          # Mock sleep on the job instance
          expect(job_instance).to receive(:sleep).and_return(nil)
          expect { job_instance.perform_now }.not_to raise_error

          expect(enqueued_jobs.size).to eq(1)
          enqueued_job = enqueued_jobs.last
          expect(Time.at(enqueued_job[:at])).to be_within(1.second).of(Time.current + 2.seconds)
          expect(meta_data_with_sleep.reload.enqueued?).to be true
        end
      end
    end

    context "when sleep_on_guard_locked is false (default)" do
      let(:full_pollable) { FullPollable.create!(name: "Full") }
      let(:full_meta_data) { full_pollable.pollable_meta_data }

      it "retries the job with a staggered delay" do
        travel_to Time.current do
          described_class.perform_later(full_meta_data.id)
          full_meta_data.enqueue!

          perform_enqueued_jobs

          expect(full_meta_data.reload.enqueued?).to be true
          expect(enqueued_jobs.size).to eq(1)

          enqueued_job = enqueued_jobs.last
          base_delay = (guard_locked_error.timeout - Time.now).to_f

          stagger_delay = 1 * full_pollable.guard.cooldown.to_f
          expected_wait = base_delay + stagger_delay

          # 2 second jitter
          expect(Time.at(enqueued_job[:at])).to be_within(2.second).of(Time.current + expected_wait.seconds)
          expect(Aeternitas::UniqueJobLock.count).to eq(1)
        end
      end
    end
  end
end
