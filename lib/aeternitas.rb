require "ostruct"
require "active_support/all"
require "redis"
require "connection_pool"
require "sidekiq-unique-jobs"
require "tabs_tabs"
require "aeternitas/version"
require "aeternitas/guard"
require "aeternitas/pollable"
require "aeternitas/pollable_meta_data"
require "aeternitas/source"
require "aeternitas/polling_frequency"
require "aeternitas/errors"
require "aeternitas/storage_adapter"
require "aeternitas/sidekiq"
require "aeternitas/metrics"

# Aeternitas
module Aeternitas
  # Get the configured redis connection
  # @return [ConnectionPool::Wrapper] returns a redis connection from the pool
  def self.redis
    @redis ||= ConnectionPool::Wrapper.new(size: 5, timeout: 3) { Redis.new(config.redis) }
  end

  # Access the configuration
  # @return [Aeternitas::Configuration] the Aeternitas configuration
  def self.config
    @config ||= Configuration.new
  end

  # Configure Aeternitas
  # @see Aeternitas::Configuration
  # @yieldparam [Aeternitas::Configuration] config the aeternitas configuration
  def self.configure
    yield(config)
  end

  # Enqueues all active pollables for which next polling is lower than the current time
  def self.enqueue_due_pollables
    Aeternitas::PollableMetaData.due.find_each do |pollable_meta_data|
      Aeternitas::Sidekiq::PollJob
        .set(queue: pollable_meta_data.pollable.pollable_configuration.queue)
        .perform_async(pollable_meta_data.id)
      pollable_meta_data.enqueue
      pollable_meta_data.save
    end
  end

  # Stores the global Aeternitas configuration
  # @!attribute [rw] redis
  #   Redis configuration hash, Default: nil
  # @!attribute [rw] storage_adapter_config
  #   Storage adapter configuration, See {Aeternitas::StorageAdapter} for configuration options
  # @!attribute [rw] storage_adapter
  #   Storage adapter class. Default: {Aeternitas::StorageAdapter::File}
  class Configuration
    attr_accessor :storage_adapter, :storage_adapter_config
    attr_reader :redis

    def initialize
      @storage_adapter = Aeternitas::StorageAdapter::File
      @storage_adapter_config = {
        directory: defined?(Rails) ? File.join(Rails.root, %w[aeternitas_data]) : File.join(Dir.getwd, "aeternitas_data")
      }
    end

    # Creates a new StorageAdapter instance with the given options
    # @return [Aeternitas::StoragesAdapter] new storage adapter instance
    def get_storage_adapter
      @storage_adapter.new(storage_adapter_config)
    end

    def redis=(redis_config)
      @redis = redis_config
      TabsTabs.configure { |tabstabs_config| tabstabs_config.redis = redis_config }
    end
  end
end
