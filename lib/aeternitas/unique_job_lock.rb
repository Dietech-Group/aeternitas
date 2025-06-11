require "active_record"

module Aeternitas
  # Stores locks for ensuring ActiveJob uniqueness.
  class UniqueJobLock < ActiveRecord::Base
    self.table_name = "aeternitas_unique_job_locks"

    validates :lock_digest, presence: true, uniqueness: true
    validates :expires_at, presence: true
  end
end
