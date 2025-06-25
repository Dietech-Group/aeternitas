module Aeternitas
  # Provides methods for cleaning up Aeternitas data.
  module Maintenance
    def self.cleanup_all
      cleanup_stale_locks
      cleanup_old_metrics
    end

    # Clean up stale job and guard locks that have passed their expiration.
    def self.cleanup_stale_locks
      logger = ActiveJob::Base.logger
      logger.info "Cleaning up stale Aeternitas locks..."

      unique_job_locks_deleted = Aeternitas::UniqueJobLock.where("expires_at < ?", Time.current).delete_all
      guard_locks_deleted = Aeternitas::GuardLock.where("locked_until < ?", Time.current).delete_all

      logger.info "  - Deleted #{unique_job_locks_deleted} stale unique job locks."
      logger.info "  - Deleted #{guard_locks_deleted} stale guard locks."
      logger.info "Stale lock cleanup complete."
    end

    # Clean up old metric records to prevent the table from growing too large.
    def self.cleanup_old_metrics
      logger = ActiveJob::Base.logger
      cutoff_date = Aeternitas.config.metric_retention_period.ago

      logger.info "Cleaning up Aeternitas metrics older than #{cutoff_date}..."

      metrics_deleted = Aeternitas::Metric.where("created_at < ?", cutoff_date).delete_all

      logger.info "  - Deleted #{metrics_deleted} old metric records."
      logger.info "Old metrics cleanup complete."
    end
  end
end
