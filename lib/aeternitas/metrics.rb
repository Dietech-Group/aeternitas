module Aeternitas
  # Provides a simplified metrics system for Aeternitas.
  # Every metric is scoped by pollable class and logged in the `aeternitas_metrics` table.
  #
  # Available metrics are:
  #   - polls => Number of polling runs
  #   - successful_polls => Number of successful polling runs
  #   - failed_polls => Number of failed polling runs (includes IgnoredErrors,
  #     excludes deactivation errors and Lock errors)
  #   - ignored_errors => Number of raised {Aeternitas::Errors::Ignored}
  #   - deactivations => Number of deactivations
  #   - execution_time => Job execution time in seconds
  #   - guard_locked => Number of encountered locked guards
  #   - guard_timeout => Time until the guard is unlocked in seconds
  #   - guard_timeout_exceeded => Number of jobs that ran longer than the guards timeout
  #   - pollables_created => Number of created pollables
  #   - sources_created => Number of created sources
  #
  # @example
  #   Aeternitas::Metrics.log(:polls, MyPollable)
  #   Aeternitas::Metrics.log_value(:execution_time, MyPollable, 1.25)
  #
  #   # Get all poll counts for MyPollable in the last day
  #   Aeternitas::Metrics.get(:polls, MyPollable, from: 1.day.ago)
  #
  module Metrics
    # A list of all available metric names.
    AVAILABLE_METRICS = [
      :polls,
      :successful_polls,
      :failed_polls,
      :ignored_errors,
      :deactivations,
      :execution_time,
      :guard_locked,
      :guard_timeout,
      :guard_timeout_exceeded,
      :sources_created,
      :pollables_created
    ].freeze

    # Logs a counter metric. This creates a new metric record with a value of 1.
    # @param [Symbol] name the metric name
    # @param [Class] pollable_class the class of the pollable
    def self.log(name, pollable_class)
      log_value(name, pollable_class, 1)
    end

    # Logs a value-based metric.
    # @param [Symbol] name the metric name
    # @param [Class] pollable_class the class of the pollable
    # @param [Float] value the value to log
    def self.log_value(name, pollable_class, value)
      return unless Aeternitas.config.metrics_enabled && AVAILABLE_METRICS.include?(name)

      Aeternitas::Metric.create(
        name: name.to_s,
        pollable_class: pollable_class.name,
        value: value,
        created_at: Time.now
      )
    rescue
      # Metrics should fail silently
    end

    # Retrieves metric records.
    # @param [Symbol] name the metric
    # @param [Class] pollable_class the pollable class
    # @param [Time] from begin of the time frame
    # @param [Time] to end of the timeframe
    # @return [ActiveRecord::Relation] a relation of Aeternitas::Metric records
    def self.get(name, pollable_class, from: 1.hour.ago, to: Time.now)
      Aeternitas::Metric.where(
        name: name.to_s,
        pollable_class: pollable_class.name,
        created_at: from..to
      ).order(:created_at)
    end
  end
end
