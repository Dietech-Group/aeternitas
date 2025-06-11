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
        digest = self.class.generate_lock_digest(pollable_meta_data_id)

        Aeternitas::UniqueJobLock.where("lock_digest = ? AND expires_at <= ?", digest, Time.now).destroy_all

        new_lock = Aeternitas::UniqueJobLock.new(
          lock_digest: digest,
          expires_at: Time.now + LOCK_EXPIRATION,
          job_id: job.job_id
        )

        unless new_lock.save
          ActiveJob::Base.logger.warn "[Aeternitas::PollJob] Aborting enqueue for #{pollable_meta_data_id} (job #{job.job_id}) due to existing lock: #{digest}"
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
