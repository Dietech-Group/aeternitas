# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2025-08-11

This is a major rewrite of Æternitas with the primary goals of removing the Redis and Sidekiq dependencies and simplifying the core functionality.

### Changed
- Updated Core Dependencies: The gem now requires Ruby 3.1+ and ActiveRecord/ActiveJob `>= 7.0`.
- Complete Backend Overhaul: Æternitas no longer depends on Redis or Sidekiq. It now uses a pure ActiveRecord and ActiveJob backend.
- Job Uniqueness: Replaced the `sidekiq-unique-jobs` dependency with a built-in, database-backed uniqueness mechanism (`Aeternitas::UniqueJobLock`) to ensure only one `PollJob` per pollable can be enqueued at a time.
- Job Processing: Replaced Sidekiq-specific workers with a backend-agnostic `Aeternitas::PollJob` that works with any ActiveJob adapter (e.g., SolidQueue, GoodJob).
- Locking Mechanism: Replaced the Redis-backed Guard with a robust, database-backed distributed lock (`Aeternitas::GuardLock`) using pessimistic locking to prevent race conditions.
- Metrics System: Replaced the complex, Redis-based `tabstabs` metrics with a simple, database-backed system (`Aeternitas::Metric`). Metrics are now disabled by default.
- Default Source Storage Path: The default directory for the file storage adapter was changed to `storage/aeternitas/` within a Rails application.

### Added
- Thundering Herd Prevention: The `PollJob` now intelligently staggers retries when a `GuardIsLocked` error occurs, preventing many jobs from retrying simultaneously and overwhelming a resource.
- Configurable Metrics: Added `Aeternitas.config.metrics_enabled` and `Aeternitas.config.metric_retention_period` to give users control over metrics collection and data retention.
- Built-in Maintenance Jobs: Added `Aeternitas::CleanupStaleLocksJob` and `Aeternitas::CleanupOldMetricsJob` to provide a clear, easy way to schedule necessary database cleanup.
- Test Mode: Added `Aeternitas::Test.test_mode`, which sets all cooldowns, retry delays, and sleep durations to zero to simplify writing tests.

### Removed
- Removed direct gem dependencies on `sidekiq`, `sidekiq-unique-jobs`, `redis`, `connection_pool`, and `tabstabs`.
- Removed the Sidekiq-specific middleware for handling `GuardIsLocked` errors.
- Removed the complex, multi-resolution time-series logic from the metrics system.

## [0.2.0 and older] - See legacy repository
- Initial versions of Æternitas: https://github.com/FHG-IMW/aeternitas
- Relied on a Sidekiq and Redis backend for job processing, locking, and metrics.