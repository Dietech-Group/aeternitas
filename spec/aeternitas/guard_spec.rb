require "spec_helper"
require "concurrent"

describe Aeternitas::Guard do
  let(:lock_key) { "MyId" }
  let(:cooldown) { 5.seconds }
  let(:timeout) { 10.minutes }
  let(:guard) { Aeternitas::Guard.new(lock_key, cooldown, timeout) }

  RSpec.shared_examples "a guard that denies access" do
    it "does not run the block" do
      change_me = false
      expect { guard.with_lock { change_me = true } }.to raise_error(Aeternitas::Guard::GuardIsLocked)
      expect(change_me).to be false
    end

    it "raises GuardIsLocked error with the correct timeout" do
      expect { guard.with_lock {} }.to raise_error(Aeternitas::Guard::GuardIsLocked) do |e|
        expect(e.timeout).to be_within(1.second).of(expected_timeout)
      end
    end

    it "does not change the lock" do
      existing_token = Aeternitas::GuardLock.find_by(lock_key: lock_key).token
      expect { guard.with_lock {} }.to raise_error(Aeternitas::Guard::GuardIsLocked)
      db_lock = Aeternitas::GuardLock.find_by(lock_key: lock_key)
      expect(db_lock.token).to eq(existing_token)
      expect(db_lock.token).not_to eq(guard.token)
    end
  end

  describe "#with_lock" do
    context "when the lock is available" do
      it "runs the block" do
        change_me = false
        guard.with_lock { change_me = true }
        expect(change_me).to be true
      end

      it "creates a lock record in cooldown state after execution" do
        guard.with_lock {}
        lock_record = Aeternitas::GuardLock.find_by(lock_key: lock_key)
        expect(lock_record).to be_present
        expect(lock_record.cooldown?).to be true
        expect(lock_record.locked_until).to be_within(1.second).of(cooldown.from_now)
      end
    end

    context "when the lock is held by another process" do
      let(:expected_timeout) { timeout.from_now }
      before do
        Aeternitas::GuardLock.create!(
          lock_key: lock_key,
          state: :processing,
          token: "other-token",
          locked_until: timeout.from_now
        )
      end

      it_behaves_like "a guard that denies access"
    end

    context "when the lock is in cooldown" do
      let(:expected_timeout) { cooldown.from_now }
      before do
        Aeternitas::Guard.new(lock_key, cooldown, timeout).with_lock {}
      end

      it_behaves_like "a guard that denies access"
    end

    context "when the lock is sleeping" do
      let(:expected_timeout) { 20.minutes.from_now }
      before do
        Aeternitas::Guard.new(lock_key, cooldown, timeout).sleep_until(expected_timeout)
      end

      it_behaves_like "a guard that denies access"
    end

    context "when an existing lock has expired" do
      # Loop through all the states
      [:processing, :sleeping, :cooldown].each do |expired_state|
        context "from the '#{expired_state}' state" do
          before do
            Aeternitas::GuardLock.create!(
              lock_key: lock_key,
              state: expired_state,
              token: "other-token",
              locked_until: 1.minute.ago
            )
          end

          it "takes over the lock and runs the block" do
            change_me = false
            guard.with_lock { change_me = true }
            expect(change_me).to be true
          end

          it "updates the lock record to cooldown state with the new token" do
            guard.with_lock {}
            lock_record = Aeternitas::GuardLock.find_by(lock_key: lock_key)
            expect(lock_record.token).to eq(guard.token)
            expect(lock_record.cooldown?).to be true
          end
        end
      end
    end
  end

  describe "#sleep_until" do
    let(:sleep_until_time) { 5.hours.from_now }

    context "when no lock exists" do
      it "creates a new sleeping lock" do
        guard.sleep_until(sleep_until_time, "API limit")
        lock_record = Aeternitas::GuardLock.find_by(lock_key: lock_key)
        expect(lock_record).to be_present
        expect(lock_record.sleeping?).to be true
        expect(lock_record.locked_until).to be_within(1.second).of(sleep_until_time)
        expect(lock_record.reason).to eq("API limit")
      end
    end

    context "when a lock already exists" do
      before do
        Aeternitas::GuardLock.create!(
          lock_key: lock_key,
          state: :processing,
          token: "other-token",
          locked_until: 1.minute.from_now
        )
      end

      it "updates the existing lock to sleeping state" do
        guard.sleep_until(sleep_until_time)
        lock_record = Aeternitas::GuardLock.find_by(lock_key: lock_key)
        expect(lock_record.sleeping?).to be true
        expect(lock_record.token).to eq(guard.token)
        expect(lock_record.locked_until).to be_within(1.second).of(sleep_until_time)
      end
    end
  end

  describe "Concurrency" do
    let(:concurrent_lock_key) { "ConcurrentLock" }

    context "when multiple processes try to create the same lock" do
      it "only allows one to succeed without raising errors" do
        success_count = Concurrent::AtomicFixnum.new(0)
        error_count = Concurrent::AtomicFixnum.new(0)

        threads = 3.times.map do
          Thread.new do
            # Each thread needs its own DB connection from the pool
            ActiveRecord::Base.connection_pool.with_connection do
              new_guard = Aeternitas::Guard.new(concurrent_lock_key, 0.1.seconds)
              new_guard.with_lock do
                success_count.increment
                sleep 0.1
              end
            end
          rescue Aeternitas::Guard::GuardIsLocked
            error_count.increment
          end
        end

        threads.each(&:join)

        expect(success_count.value).to eq(1)
        expect(error_count.value).to eq(2)
        expect(Aeternitas::GuardLock.where(lock_key: concurrent_lock_key).count).to eq(1)
      end
    end
  end

  describe "in test mode" do
    around do |example|
      Aeternitas::Test.test_mode do
        example.run
      end
    end

    it "initializes with a cooldown of 0" do
      expect(guard.cooldown).to eq(0.seconds)
    end

    it "sleeps until now" do
      guard.sleep_until(1.hour.from_now)
      lock_record = Aeternitas::GuardLock.find_by(lock_key: lock_key)
      expect(lock_record.locked_until).to be_within(1.second).of(Time.now)
    end
  end
end
