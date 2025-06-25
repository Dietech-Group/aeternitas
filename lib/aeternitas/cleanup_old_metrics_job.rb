require_relative "aeternitas_job"

module Aeternitas
  # An ActiveJob for cleaning up old metric records.
  class CleanupOldMetricsJob < AeternitasJob
    queue_as :maintenance

    def perform
      Aeternitas::Maintenance.cleanup_old_metrics
    end
  end
end
