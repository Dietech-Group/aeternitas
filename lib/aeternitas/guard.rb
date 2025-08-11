require "active_support/duration"
require "securerandom"

module Aeternitas
  # A distributed lock that can not be acquired after being unlocked for a certain time (cooldown period).
  # Using a database table (`aeternitas_guard_locks`) with pessimistic locking we ensure atomicity and prevent race conditions.
  #
  # @example
  #   guard = Aeternitas::Guard.new("Twitter-MY_API_KEY", 5.seconds)
  #   begin
  #     guard.with_lock do
  #       twitter_client.user_timeline('Darth_Max')
  #     end
  #   rescue Twitter::TooManyRequests => e
  #     guard.sleep_until(e.rate_limit.reset_at)
  #     raise Aeternitas::Guard::GuardIsLocked.new(e.rate_limit.reset_at)
  #   end
  #
  # @!attribute [r] id
  #   @return [String] the guards id
  # @!attribute [r] timeout
  #   @return [ActiveSupport::Duration] the locks timeout duration
  # @!attribute [r] cooldown
  #   @return [ActiveSupport::Duration] cooldown time, in which the lock can't be acquired after being released
  # @!attribute [r] token
  #   @return [String] cryptographic token which ensures we do not lock/unlock a guard held by another process
  class Guard
    attr_reader :id, :timeout, :cooldown, :token

    # Create a new Guard
    #
    # @param [String] id Lock id
    # @param [ActiveRecord::Duration] cooldown Cooldown time
    # @param [ActiveRecord::Duration] timeout Lock timeout
    # @return [Aeternitas::Guard] Creates a new Instance
    def initialize(id, cooldown, timeout = 10.minutes)
      @id = id
      @cooldown = Aeternitas.test_mode? ? 0.seconds : cooldown
      @timeout = timeout
      @token = SecureRandom.hex(10)
    end

    # Runs a given block if the lock can be acquired and releases the lock afterwards.
    #
    # @raise [Aeternitas::Guard::GuardIsLocked] if the lock can not be acquired
    # @example
    #   Guard.new("MyId", 5.seconds, 10.minutes).with_lock { do_request() }
    def with_lock
      acquire_lock!
      begin
        yield
      ensure
        unlock
      end
    end

    # Tries to unlock the guard and starts the cooldown phase.
    # It only releases the lock if the token matches and the state is 'processing'.
    def unlock
      Aeternitas::GuardLock.transaction do
        lock = Aeternitas::GuardLock.where(lock_key: @id, token: @token).lock.first
        return false unless lock&.processing?

        lock.update!(
          state: :cooldown,
          locked_until: @cooldown.from_now,
          reason: nil
        )
      end
      true
    end

    # Locks the guard until the given time.
    #
    # @param [Time] until_time sleep time
    # @param [String] msg hint why the guard sleeps
    def sleep_until(until_time, msg = nil)
      sleep(until_time, msg)
    end

    # Locks the guard for the given duration.
    #
    # @param [ActiveSupport::Duration] duration sleeping duration
    # @param [String] msg hint why the guard sleeps
    def sleep_for(duration, msg = nil)
      raise ArgumentError, "duration must be an ActiveRecord::Duration" unless duration.is_a?(ActiveSupport::Duration)
      sleep_until(duration.from_now, msg)
    end

    private

    # Tries to acquire the lock.
    # @raise [Aeternitas::Guard::GuardIsLocked] if the lock can not be acquired
    def acquire_lock!
      retries = 0
      begin
        Aeternitas::GuardLock.transaction do
          lock = Aeternitas::GuardLock.where(lock_key: @id).lock.first

          if lock
            if lock.locked_until > Time.current
              # Lock is still active
              raise GuardIsLocked.new(@id, lock.locked_until, lock.reason)
            else
              # Lock has expired
              lock.update!(
                token: @token,
                state: :processing,
                locked_until: @timeout.from_now,
                reason: nil
              )
            end
          else
            # Create new lock
            Aeternitas::GuardLock.create!(
              lock_key: @id,
              token: @token,
              state: :processing,
              locked_until: @timeout.from_now
            )
          end
        end
      rescue ActiveRecord::RecordNotUnique
        # prevent infinite loops in unexpected scenarios
        retries += 1
        raise if retries > 4
        retry
      end
    end

    # Lets the guard sleep until the given time.
    # This will create a new sleeping lock or update an existing one.
    # @todo Should this raise an error if the lock is not owned by this instance?
    # @param [Time] sleep_timeout for how long will the guard sleep
    # @param [String] msg hint why the guard sleeps
    def sleep(sleep_timeout, msg = nil)
      sleep_timeout = Time.now if Aeternitas.test_mode?
      Aeternitas::GuardLock.transaction do
        lock = Aeternitas::GuardLock.where(lock_key: @id).lock.first_or_initialize

        lock.assign_attributes(
          token: @token,
          state: :sleeping,
          locked_until: sleep_timeout,
          reason: msg
        )

        lock.save!
      end
    end

    # Custom error class thrown when the lock can not be acquired
    # @!attribute [r] timeout
    #   @return [DateTime] the locks current timeout
    class GuardIsLocked < StandardError
      attr_reader :timeout

      def initialize(resource_id, timeout, reason = nil)
        msg = "Resource '#{resource_id}' is locked until #{timeout}."
        msg += " Reason: #{reason}" if reason
        super(msg)
        @timeout = timeout
      end
    end
  end
end
