require_relative "aeternitas_job"

module Aeternitas
  # An ActiveJob for cleaning up stale lock records.
  class CleanupStaleLocksJob < AeternitasJob
    queue_as :maintenance

    def perform
      Aeternitas::Maintenance.cleanup_stale_locks
    end
  end
end
