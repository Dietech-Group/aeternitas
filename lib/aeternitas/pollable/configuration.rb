module Aeternitas
  module Pollable
    # Holds the configuration of a pollable class
    # @!attribute [rw] polling_frequency
    #   Method that calculates the next polling time after a successful poll.
    #   (Default: {Aeternitas::PollingFrequency::DAILY})
    # @!attribute [rw] before_polling
    #   Methods to be run before each poll
    # @!attribute [rw] after_polling
    #   Methods to be run after each successful poll
    # @!attribute [rw] queue
    #   Sidekiq queue the poll job will be enqueued in (Default: 'polling')
    # @!attribute [rw] guard_options
    #   Configuration of the pollables lock (Default: key => class+id, cooldown => 5.seconds, timeout => 10.minutes)
    # @!attribute [rw] deactivation_errors
    #   The pollable instance will be deactivated if any of these errors occur while polling
    # @!attribute [rw] ignored_errors
    #   Errors in this list will be wrapped by {Aeternitas::Error::Ignored} if they occur while polling
    #   (i.e. ignore in your exception tracker)
    # @!attribute [rw] sleep_on_guard_locked
    #   When set to true poll jobs (and effectively the Sidekiq worker thread) will sleep until the
    #   lock is released if the lock could not be acquired. (Default: true)
    class Configuration
      attr_accessor :deactivation_errors,
        :before_polling,
        :queue,
        :polling_frequency,
        :after_polling,
        :guard_options,
        :ignored_errors,
        :sleep_on_guard_locked

      # Creates a new Configuration with default options
      def initialize
        @polling_frequency = Aeternitas::PollingFrequency::DAILY
        @before_polling = []
        @after_polling = []
        @guard_options = {
          key: ->(obj) { obj.class.name.to_s },
          timeout: 10.minutes,
          cooldown: 5.seconds
        }
        @deactivation_errors = []
        @ignored_errors = []
        @queue = "polling"
        @sleep_on_guard_locked = true
      end

      def copy
        config = Configuration.new
        config.polling_frequency = polling_frequency
        config.before_polling = before_polling.deep_dup
        config.after_polling = after_polling.deep_dup
        config.guard_options = guard_options.deep_dup
        config.deactivation_errors = deactivation_errors.deep_dup
        config.ignored_errors = ignored_errors.deep_dup
        config.queue = queue
        config.sleep_on_guard_locked = sleep_on_guard_locked
        config
      end
    end
  end
end
