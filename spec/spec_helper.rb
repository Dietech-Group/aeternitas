$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "active_record"
require "active_job"
require "active_support/testing/time_helpers"
require "aeternitas"
require "database_cleaner"
require "database_cleaner/redis"

# Configure ActiveJob test adapter
ActiveJob::Base.queue_adapter = :test

# configure active record
ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
load File.dirname(__FILE__) + "/schema.rb"
require File.dirname(__FILE__) + "/pollables.rb"
# configure aeternitas
Aeternitas.configure do |conf|
  conf.redis = {host: "127.0.0.1"}
  conf.storage_adapter_config = {
    directory: "/tmp/aeternitas_tests/"
  }
end

DatabaseCleaner[:active_record].strategy = :transaction
DatabaseCleaner[:redis].strategy = :deletion

RSpec.configure do |config|
  config.order = :random # Tests should not depend on each other

  config.include ActiveJob::TestHelper
  config.include ActiveSupport::Testing::TimeHelpers

  config.before(:suite) do
    # Clean once before suite using schema.rb definitions with force: true
    DatabaseCleaner[:active_record].clean_with :truncation
    DatabaseCleaner[:redis].clean_with :deletion
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.around(:each, tmpFiles: true) do |example|
    example.run
  ensure
    FileUtils.rm_rf(Aeternitas.config.storage_adapter_config[:directory])
  end

  # Clear jobs before each test example
  config.before(:each) do
    clear_enqueued_jobs
    clear_performed_jobs
  end
end
