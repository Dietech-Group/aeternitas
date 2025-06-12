require_relative "application_job"
require "digest"

module Aeternitas
  # ActiveJob worker responsible for executing the polling.
  class PollJob < ApplicationJob
    queue_as :polling

    LOCK_EXPIRATION = 1.month
    RETRY_DELAYS = [60.seconds, 1.hour, 1.day, 1.week].freeze
    MAX_TOTAL_ATTEMPTS = 5

    # === Job Uniqueness ===
    before_enqueue do |job|
      # Only check for uniqueness on the first attempt. Retries should not be blocked by their own lock.
      if job.executions.zero?
        pollable_meta_data_id = job.arguments.first
        pollable_meta_data = Aeternitas::PollableMetaData.find(pollable_meta_data_id)
        pollable = pollable_meta_data.pollable

        lock_digest = self.class.generate_lock_digest(pollable_meta_data_id)
        guard_key_digest = self.class.generate_guard_key_digest(pollable)

        Aeternitas::UniqueJobLock.where("lock_digest = ? AND expires_at <= ?", lock_digest, Time.now).destroy_all

        new_lock = Aeternitas::UniqueJobLock.new(
          lock_digest: lock_digest,
          guard_key_digest: guard_key_digest,
          expires_at: Time.now + LOCK_EXPIRATION,
          job_id: job.job_id
        )

        unless new_lock.save
          ActiveJob::Base.logger.warn "[Aeternitas::PollJob] Aborting enqueue for #{pollable_meta_data_id} (job #{job.job_id}) due to existing lock: #{lock_digest}"
          throw(:abort)
        end
      end
    end

    # === Retry Logic ===
    retry_on StandardError,
      attempts: MAX_TOTAL_ATTEMPTS,
      wait: ->(executions) { execution_wait_time(executions) },
      jitter: ->(executions) { [execution_wait_time(executions) * 0.1, 10.minutes].min } do |job, error|
      handle_retries_exhausted(error)
    end

    # === GuardIsLocked Handling ===
    rescue_from Aeternitas::Guard::GuardIsLocked do |error|
      meta_data = Aeternitas::PollableMetaData.find_by(id: arguments.first)
      return unless meta_data

      pollable = meta_data.pollable
      pollable_config = pollable.pollable_configuration
      base_delay = (error.timeout - Time.now).to_f
      meta_data.enqueue!

      if pollable_config.sleep_on_guard_locked
        if base_delay > 0
          ActiveJob::Base.logger.warn "[Aeternitas::PollJob] Guard locked for #{arguments.first}. Sleep for #{base_delay.round(2)}s."
          sleep(base_delay)
        end
        retry_job(wait: 2.seconds)
      else
        guard_key_digest = self.class.generate_guard_key_digest(pollable)
        lock_digest = self.class.generate_lock_digest(arguments.first)
        unique_lock = Aeternitas::UniqueJobLock.find_by(lock_digest: lock_digest)

        rank = if unique_lock
          Aeternitas::UniqueJobLock.where(guard_key_digest: guard_key_digest)
            .where("created_at <= ?", unique_lock.created_at)
            .count
        else
          Aeternitas::UniqueJobLock.where(guard_key_digest: guard_key_digest).count
        end

        stagger_delay = rank * pollable.guard.cooldown.to_f
        jitter = rand(0.0..2.0)
        total_wait = base_delay + stagger_delay + jitter

        if total_wait > 0
          retry_job(wait: total_wait.seconds)
          ActiveJob::Base.logger.info "[Aeternitas::PollJob] Guard locked for #{arguments.first}. Retry in #{total_wait.round(2)}s."
        else
          # GuardLock expired, retry with minimal delay
          retry_job(wait: jitter.seconds)
        end
      end
    end

    def self.execution_wait_time(executions)
      wait_index = executions - 1
      RETRY_DELAYS[wait_index] || RETRY_DELAYS.last
    end

    def perform(pollable_meta_data_id)
      meta_data = Aeternitas::PollableMetaData.find_by(id: pollable_meta_data_id)
      if meta_data
        pollable = meta_data.pollable
        pollable&.execute_poll
      else
        ActiveJob::Base.logger.warn "[Aeternitas::PollJob] PollableMetaData with ID #{pollable_meta_data_id} not found."
      end
    end

    after_perform -> { cleanup_lock("success") }

    def self.generate_lock_digest(pollable_meta_data_id)
      Digest::SHA256.hexdigest("#{name}:#{pollable_meta_data_id}")
    end

    def self.generate_guard_key_digest(pollable)
      guard_key = pollable.pollable_configuration.guard_options[:key].call(pollable)
      Digest::SHA256.hexdigest("guard-key:#{guard_key}")
    end

    def handle_retries_exhausted(error)
      ActiveJob::Base.logger.error "[Aeternitas::PollJob] Retries exhausted for job #{job_id}. Error: #{error&.class} - #{error&.message}"
      pollable_meta_data_id = arguments.first
      meta_data = Aeternitas::PollableMetaData.find_by(id: pollable_meta_data_id)
      meta_data&.disable_polling("Retries exhausted. Last error: #{error&.message}")
      cleanup_lock("retries_exhausted")
    end

    def cleanup_lock(reason = "unknown")
      return unless arguments.is_a?(Array) && arguments.first

      pollable_meta_data_id = arguments.first
      digest = self.class.generate_lock_digest(pollable_meta_data_id)
      lock = Aeternitas::UniqueJobLock.find_by(lock_digest: digest)
      lock&.destroy
    end
  end
end
