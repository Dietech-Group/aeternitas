require "active_record"

module Aeternitas
  # Since ActiveJob lacks a built-in uniqueness feature, this model prevents duplicate jobs from running simultaneously.
  # This is achieved using the unique key `lock_digest`, which is calculated for each job instance.
  # Additionally, this model stores `guard_key_digest` — a hash of the pollable's guard key —
  # to determine how many jobs are waiting on the same resource and to adjust retries accordingly.
  # Finally, `expires_at` is used to clean up stale locks left by crashed workers.
  class UniqueJobLock < ActiveRecord::Base
    self.table_name = "aeternitas_unique_job_locks"

    validates :lock_digest, presence: true, uniqueness: true
    validates :expires_at, presence: true
  end
end
